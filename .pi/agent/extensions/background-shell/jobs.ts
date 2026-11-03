import { spawn, type ChildProcess } from "node:child_process";
import { closeSync, fstatSync, mkdtempSync, openSync, readSync } from "node:fs";
import { constants, tmpdir } from "node:os";
import { join } from "node:path";
import { getShellConfig } from "@earendil-works/pi-coding-agent";

export type JobStatus =
  "running" | "completed" | "failed" | "killed" | "timed_out";
export interface ShellJob {
  id: string;
  command: string;
  cwd: string;
  path: string;
  pid?: number;
  startedAt: number;
  endedAt?: number;
  status: JobStatus;
  exitCode: number | null;
  background: boolean;
  error?: string;
  finished: Promise<void>;
}

export class Backgrounded extends Error {
  constructor(public job: ShellJob) {
    super(`Shell job ${job.id} continues in the background`);
  }
}

const MAX_TAIL_BYTES = 48 * 1024;
const MAX_JOBS = 100;
const MAX_RUNNING = 16;

export function readJobOutput(
  job: ShellJob,
  maxBytes = MAX_TAIL_BYTES,
): string {
  const fd = openSync(job.path, "r");
  try {
    const size = fstatSync(fd).size;
    const start = Math.max(0, size - maxBytes);
    const bytes = Buffer.alloc(size - start);
    readSync(fd, bytes, 0, bytes.length, start);
    return `${start > 0 ? "[Showing output tail]\n" : ""}${bytes.toString("utf8")}`;
  } finally {
    closeSync(fd);
  }
}

export class ShellJobs {
  readonly jobs = new Map<string, ShellJob>();
  private foreground = new Map<string, () => void>();
  private timers = new Set<ReturnType<typeof setTimeout>>();
  private directory?: string;
  private nextId = 1;
  private closed = false;

  constructor(
    private changed: () => void,
    private completed: (job: ShellJob) => void,
  ) {}

  start(
    command: string,
    cwd: string,
    env: NodeJS.ProcessEnv,
    shellPath?: string,
    timeout?: number,
  ): ShellJob {
    if (this.closed) throw new Error("Shell job manager is closed");
    if (this.running().length >= MAX_RUNNING)
      throw new Error(`At most ${MAX_RUNNING} shells may run at once`);
    if (
      timeout !== undefined &&
      (!Number.isFinite(timeout) ||
        timeout <= 0 ||
        timeout * 1000 > 2_147_483_647)
    ) {
      throw new Error(
        "Timeout must be a positive number of seconds, at most 2147483",
      );
    }
    for (const [id, job] of this.jobs) {
      if (this.jobs.size < MAX_JOBS) break;
      if (job.status !== "running") this.jobs.delete(id);
    }
    this.directory ??= mkdtempSync(join(tmpdir(), "pi-shell-jobs-"));
    const id = `shell-${this.nextId++}`;
    const path = join(this.directory, `${id}.log`);
    const shell = getShellConfig(shellPath);
    const fd = openSync(path, "wx", 0o600);
    let child: ChildProcess;
    try {
      child = spawn(shell.shell, [...shell.args, command], {
        cwd,
        env,
        detached: process.platform !== "win32",
        stdio: ["ignore", fd, fd],
      });
    } finally {
      closeSync(fd);
    }
    let finish!: () => void;
    const job: ShellJob = {
      id,
      command,
      cwd,
      path,
      pid: child.pid,
      startedAt: Date.now(),
      status: "running",
      exitCode: null,
      background: false,
      finished: new Promise<void>((resolve) => {
        finish = resolve;
      }),
    };
    this.jobs.set(id, job);
    let timeoutTimer: ReturnType<typeof setTimeout> | undefined;
    const settle = (
      code: number | null,
      signal?: NodeJS.Signals | null,
      error?: Error,
    ) => {
      if (job.endedAt !== undefined) return;
      if (timeoutTimer) {
        clearTimeout(timeoutTimer);
        this.timers.delete(timeoutTimer);
      }
      job.endedAt = Date.now();
      job.exitCode =
        code ?? (signal ? 128 + (constants.signals[signal] ?? 0) : 1);
      job.error = error?.message;
      if (job.status === "running")
        job.status = job.exitCode === 0 ? "completed" : "failed";
      // A shell can exit while descendants still hold resources. Jobs own their process group.
      this.signalGroup(job, "SIGKILL");
      finish();
      if (!this.closed) {
        this.changed();
        if (job.background) this.completed(job);
      }
    };
    child.once("error", (error) => settle(null, null, error));
    child.once("exit", (code, signal) => settle(code, signal));
    if (timeout !== undefined) {
      timeoutTimer = setTimeout(
        () => this.stop(id, "timed_out"),
        timeout * 1000,
      );
      this.timers.add(timeoutTimer);
    }
    this.changed();
    return job;
  }

  running(): ShellJob[] {
    return [...this.jobs.values()].filter((job) => job.endedAt === undefined);
  }

  private signalGroup(job: ShellJob, signal: NodeJS.Signals) {
    if (!job.pid) return;
    try {
      if (process.platform === "win32") {
        spawn("taskkill", ["/pid", String(job.pid), "/T", "/F"], {
          stdio: "ignore",
        });
      } else {
        process.kill(-job.pid, signal);
      }
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ESRCH") throw error;
    }
  }

  stop(id: string, status: "killed" | "timed_out" = "killed") {
    const job = this.jobs.get(id);
    if (!job) throw new Error(`Unknown shell job: ${id}`);
    if (job.endedAt !== undefined) return;
    job.status = status;
    this.signalGroup(job, "SIGTERM");
    const timer = setTimeout(() => {
      this.timers.delete(timer);
      if (job.endedAt === undefined) this.signalGroup(job, "SIGKILL");
    }, 500);
    this.timers.add(timer);
    this.changed();
  }

  backgroundLatest(): boolean {
    const detach = [...this.foreground.values()].at(-1);
    if (!detach) return false;
    detach();
    return true;
  }

  async wait(
    job: ShellJob,
    options: {
      signal?: AbortSignal;
      yieldMs: number;
      onData: (data: Buffer) => void;
    },
  ): Promise<{ exitCode: number | null }> {
    const { signal, yieldMs, onData } = options;
    let detach!: () => void;
    let abort!: () => void;
    const detached = new Promise<"background">((resolve) => {
      detach = () => resolve("background");
    });
    const aborted = new Promise<"aborted">((resolve) => {
      abort = () => resolve("aborted");
    });
    this.foreground.set(job.id, detach);
    let position = 0;
    const stream = () => {
      const fd = openSync(job.path, "r");
      try {
        const size = fstatSync(fd).size;
        if (size <= position) return;
        const start = Math.max(position, size - MAX_TAIL_BYTES);
        if (start > position)
          onData(
            Buffer.from(
              `\n[Output skipped while streaming; full log: ${job.path}]\n`,
            ),
          );
        const bytes = Buffer.alloc(size - start);
        readSync(fd, bytes, 0, bytes.length, start);
        position = size;
        onData(bytes);
      } finally {
        closeSync(fd);
      }
    };
    const poll = setInterval(stream, 200);
    const timer = setTimeout(detach, yieldMs);
    signal?.addEventListener("abort", abort, { once: true });
    if (signal?.aborted) abort();
    try {
      const result = await Promise.race([
        job.finished.then(() => "done" as const),
        detached,
        aborted,
      ]);
      stream();
      if (result === "aborted") {
        this.stop(job.id);
        await job.finished;
        throw new Error("aborted");
      }
      if (result === "background" && job.endedAt === undefined) {
        job.background = true;
        this.changed();
        throw new Backgrounded(job);
      }
      if (job.error) throw new Error(job.error);
      if (job.status === "timed_out")
        throw new Error("Shell command timed out");
      return { exitCode: job.exitCode };
    } finally {
      clearInterval(poll);
      clearTimeout(timer);
      signal?.removeEventListener("abort", abort);
      this.foreground.delete(job.id);
    }
  }

  killAll() {
    for (const job of this.running()) {
      job.status = "killed";
      this.signalGroup(job, "SIGKILL");
    }
  }

  async close() {
    if (this.closed) return;
    this.closed = true;
    for (const timer of this.timers) clearTimeout(timer);
    this.timers.clear();
    const running = this.running();
    this.killAll();
    await Promise.all(running.map((job) => job.finished));
  }
}
