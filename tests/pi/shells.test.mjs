import assert from "node:assert/strict";
import { statSync } from "node:fs";
import { stripVTControlCharacters } from "node:util";
import test from "node:test";
import { EventEmitter } from "node:events";
import { setTimeout as delay } from "node:timers/promises";
import { harness, load, plainTheme, tui } from "./runtime.mjs";

const { ShellJobs, Backgrounded, readJobOutput } = await load(
  ".pi/agent/extensions/background-shell/jobs.ts",
);
const cwd = process.cwd();
const waitOptions = (overrides = {}) => ({
  yieldMs: 1000,
  onData() {},
  ...overrides,
});

async function queue(t) {
  const completed = [];
  const jobs = new ShellJobs(
    () => {},
    (job) => completed.push(job),
  );
  t.after(() => jobs.close());
  return { jobs, completed };
}

test("short command preserves exit code and stdout/stderr in private log", async (t) => {
  const { jobs, completed } = await queue(t);
  const job = jobs.start(
    "printf hello; printf error >&2; exit 7",
    cwd,
    process.env,
  );
  const result = await jobs.wait(job, waitOptions());
  assert.equal(result.exitCode, 7);
  assert.equal(job.status, "failed");
  assert.equal(readJobOutput(job), "helloerror");
  assert.equal(statSync(job.path).mode & 0o777, 0o600);
  assert.equal(completed.length, 0);
});

test("auto-yield returns a job, keeps running and notifies exactly once", async (t) => {
  const { jobs, completed } = await queue(t);
  const job = jobs.start(
    "printf start; sleep 0.15; printf done",
    cwd,
    process.env,
  );
  await assert.rejects(
    jobs.wait(job, waitOptions({ yieldMs: 10 })),
    (error) => error instanceof Backgrounded && error.job.id === job.id,
  );
  assert.equal(job.background, true);
  assert.equal(job.status, "running");
  await job.finished;
  assert.equal(readJobOutput(job), "startdone");
  assert.equal(completed.length, 1);
});

test("manual backgrounding detaches latest foreground and abort no longer kills it", async (t) => {
  const { jobs } = await queue(t);
  const controller = new AbortController();
  const job = jobs.start("sleep 0.15; printf done", cwd, process.env);
  const pending = jobs.wait(job, waitOptions({ signal: controller.signal }));
  assert.equal(jobs.backgroundLatest(), true);
  await assert.rejects(pending, Backgrounded);
  controller.abort();
  await job.finished;
  assert.equal(job.status, "completed");
});

test("foreground cancellation and timeout stop commands", async (t) => {
  const { jobs } = await queue(t);
  const controller = new AbortController();
  const cancelled = jobs.start("sleep 30", cwd, process.env);
  const pending = jobs.wait(
    cancelled,
    waitOptions({ signal: controller.signal }),
  );
  controller.abort();
  await assert.rejects(pending, /aborted/);
  assert.equal(cancelled.status, "killed");
  const timed = jobs.start("sleep 30", cwd, process.env, undefined, 0.05);
  await assert.rejects(jobs.wait(timed, waitOptions()), /timed out/);
  assert.equal(timed.status, "timed_out");
});

test("kill and shutdown terminate process groups, including TERM-resistant children", async (t) => {
  const { jobs } = await queue(t);
  const job = jobs.start("trap '' TERM; sleep 30 & wait", cwd, process.env);
  await delay(50);
  jobs.stop(job.id);
  await job.finished;
  assert.equal(job.status, "killed");
  assert.throws(() => process.kill(-job.pid, 0), /ESRCH/);
  const other = jobs.start("sleep 30", cwd, process.env);
  await jobs.close();
  await jobs.close();
  assert.equal(other.status, "killed");
  assert.throws(() => process.kill(-other.pid, 0), /ESRCH/);
});

test("spawn failures and invalid timeouts fail without hanging", async (t) => {
  const { jobs } = await queue(t);
  const job = jobs.start(
    "echo never",
    "/nonexistent/pi-shell-test-directory",
    process.env,
  );
  await assert.rejects(jobs.wait(job, waitOptions()), /ENOENT/);
  for (const timeout of [-1, 0, Infinity, NaN])
    assert.throws(
      () => jobs.start("true", cwd, process.env, undefined, timeout),
      /Timeout/,
    );
});

test("large output has bounded tails with a full log", async (t) => {
  const { jobs } = await queue(t);
  const job = jobs.start(
    "head -c 100000 /dev/zero | tr '\\0' x",
    cwd,
    process.env,
  );
  await jobs.wait(job, waitOptions());
  assert.equal(statSync(job.path).size, 100000);
  assert.ok(Buffer.byteLength(readJobOutput(job)) < 50000);
  assert.match(readJobOutput(job), /^\[Showing output tail\]/);
});

test("shell manager strips terminal controls and fits narrow output", async (t) => {
  const h = await harness(".pi/agent/extensions/background-shell/index.ts");
  t.after(() => h.emit("session_shutdown"));
  await h.emit("session_start");
  await h.tools.get("bash").execute(
    "control",
    {
      command: "printf '\\033[2Jbad\\btext\\tfoo\\rbar\\n'; sleep 30",
      background: true,
    },
    undefined,
    undefined,
    h.ctx,
  );
  let component;
  h.ctx.ui.custom = (factory) =>
    new Promise((resolve) => {
      component = factory({ requestRender() {} }, plainTheme, {}, resolve);
    });
  const pending = h.commands.get("shells").handler("", h.ctx);
  t.after(() => {
    component.handleInput("\x1b");
    component.dispose();
  });
  for (const width of [1, 12, 80]) {
    for (const line of component.render(width)) {
      assert.ok(tui.visibleWidth(line) <= width);
      assert.doesNotMatch(stripVTControlCharacters(line), /[\x00-\x1f\x7f]/);
    }
  }
  component.handleInput("\x1b");
  component.dispose();
  await pending;
});

test("extension preserves settings and structured output, publishes completion and cleans up", async (t) => {
  const bus = new EventEmitter();
  const h = await harness(
    ".pi/agent/extensions/background-shell/index.ts",
    bus,
  );
  t.after(() => h.emit("session_shutdown"));
  await h.emit("session_start");
  h.setSettings({ shellCommandPrefix: "export DOTFILES_TEST_PREFIX=present" });
  const bash = h.tools.get("bash");
  const fg = await bash.execute(
    "fg",
    { command: "printf $DOTFILES_TEST_PREFIX; exit 4" },
    undefined,
    undefined,
    h.ctx,
  );
  assert.equal(fg.isError, true);
  assert.equal(fg.structuredContent.exit_code, 4);
  assert.equal(fg.structuredContent.output, "present");
  let running = 0;
  bus.on("dotfiles:shell-jobs", (data) => {
    running = data.running;
  });
  const bg = await bash.execute(
    "bg",
    { command: "sleep 0.1; printf done", background: true },
    undefined,
    undefined,
    h.ctx,
  );
  assert.equal(bg.structuredContent.exit_code, null);
  assert.match(bg.structuredContent.job_id, /^shell-/);
  assert.equal(running, 1);
  assert.equal(h.statuses.get("shells"), "shells (1)");
  await delay(200);
  assert.equal(running, 0);
  assert.equal(h.messages.length, 1);
  assert.equal(h.messages[0].options.triggerTurn, true);
  assert.match(h.messages[0].content, /done/);
  const output = await h.tools
    .get("shell_jobs")
    .execute(
      "out",
      { action: "output", id: bg.structuredContent.job_id },
      undefined,
      undefined,
      h.ctx,
    );
  assert.match(output.content[0].text, /completed/);
  await bash.execute(
    "shutdown",
    { command: "sleep 30", background: true },
    undefined,
    undefined,
    h.ctx,
  );
  await h.emit("session_shutdown");
  assert.equal(h.messages.length, 1);
  assert.equal(h.statuses.has("shells"), false);
});
