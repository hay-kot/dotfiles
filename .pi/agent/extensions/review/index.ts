/**
 * /review:* — review commands backed by plannotator.
 *
 * Usage:
 *   /review:code                Review local diff vs default branch.
 *   /review:code <PR_URL>       Review the given PR/MR.
 *   /review:doc                 Pick a recent .hive/ markdown doc to review.
 *   /review:doc <path>          Review a specific markdown doc.
 */

import { execSync, spawnSync } from "node:child_process";
import { existsSync, promises as fs } from "node:fs";
import * as path from "node:path";

import type {
  ExtensionAPI,
  ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";

const HIVE_DIR = ".hive";
const TOP_N = 5;

type Candidate = { abs: string; rel: string; mtimeMs: number };

type TuiInstance = {
  stop(): void;
  start(): void;
  requestRender(force?: boolean): void;
};

let tuiInstance: TuiInstance | undefined;

function isUrl(value: string): boolean {
  return value.startsWith("http://") || value.startsWith("https://");
}

async function walkMarkdown(root: string): Promise<Candidate[]> {
  const out: Candidate[] = [];

  async function walk(dir: string) {
    let entries;
    try {
      entries = await fs.readdir(dir, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      const full = path.join(dir, entry.name);
      if (entry.isSymbolicLink()) {
        try {
          const stat = await fs.stat(full);
          if (stat.isDirectory()) {
            await walk(full);
          } else if (stat.isFile() && full.endsWith(".md")) {
            out.push({
              abs: full,
              rel: path.relative(root, full),
              mtimeMs: stat.mtimeMs,
            });
          }
        } catch {
          // Ignore dangling symlinks.
        }
        continue;
      }

      if (entry.isDirectory()) {
        await walk(full);
      } else if (entry.isFile() && entry.name.endsWith(".md")) {
        try {
          const stat = await fs.stat(full);
          out.push({
            abs: full,
            rel: path.relative(root, full),
            mtimeMs: stat.mtimeMs,
          });
        } catch {
          // Ignore unreadable files.
        }
      }
    }
  }

  await walk(root);
  return out;
}

async function topRecent(cwd: string): Promise<Candidate[]> {
  const hiveRoot = path.join(cwd, HIVE_DIR);
  const all = await walkMarkdown(hiveRoot);
  all.sort((a, b) => b.mtimeMs - a.mtimeMs);
  return all.slice(0, TOP_N);
}

async function resolveDocArg(cwd: string, arg: string): Promise<string | null> {
  const candidates = path.isAbsolute(arg)
    ? [arg]
    : [path.join(cwd, arg), path.join(cwd, HIVE_DIR, arg)];

  for (const candidate of candidates) {
    try {
      const stat = await fs.stat(candidate);
      if (stat.isFile()) return candidate;
    } catch {
      // Keep trying.
    }
  }

  return null;
}

function formatRelDate(ms: number): string {
  const diff = Date.now() - ms;
  const minutes = Math.floor(diff / 60_000);
  if (minutes < 1) return "just now";
  if (minutes < 60) return `${minutes}m ago`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;

  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

function isGitRepo(dir: string): boolean {
  try {
    execSync("git rev-parse --git-dir", { cwd: dir, stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

function parseReviewOutput(output: string): {
  hasComments: boolean;
  commentCount: number;
  text: string;
} {
  const trimmed = output.trim();
  if (!trimmed) return { hasComments: false, commentCount: 0, text: "" };

  const commentCount =
    (trimmed.match(/^### /gm) || []).length +
    (trimmed.match(/^\*\*(?:Note|Suggestion|Issue|Praise)\*\*/gm) || []).length;

  return {
    hasComments: commentCount > 0 || trimmed.length > 0,
    commentCount: Math.max(commentCount, trimmed.length > 0 ? 1 : 0),
    text: trimmed,
  };
}

function runTuicrInline(dir: string, revisions?: string): string {
  if (!tuiInstance) {
    throw new Error(
      "TUI instance not captured yet. Try again after the UI has rendered.",
    );
  }

  const args = ["--stdout", "--no-update-check"];
  if (revisions) args.push("-r", revisions);

  try {
    tuiInstance.stop();
    const result = spawnSync("tuicr", args, {
      cwd: dir,
      stdio: ["inherit", "pipe", "inherit"],
    });
    return result.stdout?.toString() ?? "";
  } finally {
    tuiInstance.start();
    tuiInstance.requestRender(true);
  }
}

function parseTuicrArgs(
  args: string,
  cwd: string,
): { dir: string; revisions?: string } {
  const parts = args.trim().split(/\s+/).filter(Boolean);
  let dir = cwd;
  let revisions: string | undefined;

  for (const part of parts) {
    const resolved = path.resolve(cwd, part);
    if (existsSync(resolved) && isGitRepo(resolved)) {
      dir = resolved;
    } else {
      revisions = part;
    }
  }

  return { dir, revisions };
}

async function handleCodeReview(
  args: string,
  ctx: ExtensionCommandContext,
  pi: ExtensionAPI,
) {
  const trimmed = args.trim();
  const plannotatorArgs = ["review"];
  let label = "local diff";

  if (trimmed) {
    if (!isUrl(trimmed)) {
      ctx.ui.notify(`Expected a PR/MR URL, got: ${trimmed}`, "error");
      return;
    }

    plannotatorArgs.push(trimmed);
    label = trimmed;
  }

  ctx.ui.setStatus("review-code", `plannotator review: ${label}`);
  try {
    const result = await pi.exec("plannotator", plannotatorArgs, {
      signal: ctx.signal,
    });
    if (result.code !== 0 && !result.killed) {
      const err =
        result.stderr.trim() || result.stdout.trim() || `exit ${result.code}`;
      ctx.ui.notify(`plannotator review failed: ${err}`, "error");
    }
  } catch (error) {
    ctx.ui.notify(
      `plannotator failed to launch: ${(error as Error).message}`,
      "error",
    );
  } finally {
    ctx.ui.setStatus("review-code", "");
  }
}

async function pickDoc(ctx: ExtensionCommandContext): Promise<string | null> {
  const recent = await topRecent(ctx.cwd);
  if (recent.length === 0) {
    ctx.ui.notify(`No .md files found under ${HIVE_DIR}/`, "warning");
    return null;
  }

  const labels = recent.map(
    (candidate) => `${candidate.rel}  (${formatRelDate(candidate.mtimeMs)})`,
  );
  const picked = await ctx.ui.select("Doc to review", labels);
  if (!picked) return null;

  const index = labels.indexOf(picked);
  return recent[index]?.abs ?? null;
}

async function handleTuicrReview(
  args: string,
  ctx: ExtensionCommandContext,
  pi: ExtensionAPI,
) {
  const { dir, revisions } = parseTuicrArgs(args, ctx.cwd);

  if (!isGitRepo(dir)) {
    ctx.ui.notify(`Not a git repository: ${dir}`, "error");
    return;
  }

  try {
    const output = runTuicrInline(dir, revisions);
    const parsed = parseReviewOutput(output);

    if (!parsed.hasComments) {
      ctx.ui.notify(
        "No review comments exported. Use 'y' in tuicr to export before quitting.",
        "warning",
      );
      return;
    }

    ctx.ui.setWidget("tuicr-review", [
      `📝 Review: ${parsed.commentCount} comment${parsed.commentCount !== 1 ? "s" : ""} received`,
    ]);

    pi.sendUserMessage(
      `Here is my code review from tuicr. Please address all comments:\n\n${parsed.text}`,
    );

    setTimeout(() => ctx.ui.setWidget("tuicr-review", undefined), 30_000);
  } catch (error) {
    ctx.ui.notify(`tuicr failed: ${error}`, "error");
  }
}

async function handleDocReview(
  args: string,
  ctx: ExtensionCommandContext,
  pi: ExtensionAPI,
) {
  const trimmed = args.trim();
  const target = trimmed
    ? await resolveDocArg(ctx.cwd, trimmed)
    : await pickDoc(ctx);

  if (!target) {
    if (trimmed) ctx.ui.notify(`File not found: ${trimmed}`, "error");
    return;
  }

  const relForDisplay = path.relative(ctx.cwd, target) || target;
  ctx.ui.setStatus("review-doc", `plannotator gate: ${relForDisplay}`);

  let stdout = "";
  let stderr = "";
  let code = 0;
  try {
    const result = await pi.exec(
      "plannotator",
      ["annotate", target, "--gate", "--json"],
      { signal: ctx.signal },
    );
    stdout = result.stdout;
    stderr = result.stderr;
    code = result.code;
  } catch (error) {
    ctx.ui.notify(
      `plannotator failed to launch: ${(error as Error).message}`,
      "error",
    );
    return;
  } finally {
    ctx.ui.setStatus("review-doc", "");
  }

  const feedback =
    stdout.trim() || stderr.trim() || "(no output from plannotator)";
  const prompt = [
    `Plannotator review of \`${relForDisplay}\` (exit ${code}).`,
    "",
    "Result (JSON from `plannotator annotate --gate --json`):",
    "",
    "```json",
    feedback,
    "```",
    "",
    `Read \`${relForDisplay}\`, apply the reviewer's feedback, and revise the document.`,
    "If the gate was approved with no changes, just confirm and stop.",
  ].join("\n");

  await pi.sendUserMessage(prompt);
}

export default function reviewExtension(pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (tuiInstance) return;
    ctx.ui.setWidget("__tuicr-tui-capture", (tui: unknown) => {
      tuiInstance = tui as TuiInstance;
      setTimeout(() => ctx.ui.setWidget("__tuicr-tui-capture", undefined), 0);
      return { render: () => [], invalidate: () => {}, dispose: () => {} };
    });
  });

  pi.registerCommand("review:code", {
    description:
      "Open plannotator review (local diff by default, or a PR/MR URL)",
    handler: async (args, ctx) => {
      await handleCodeReview(args, ctx, pi);
    },
  });

  pi.registerCommand("review:tuicr", {
    description: "Launch tuicr to interactively review code changes",
    handler: async (args, ctx) => {
      await handleTuicrReview(args, ctx, pi);
    },
  });

  pi.registerCommand("review:doc", {
    description:
      "Gate a .hive/ doc through plannotator and revise via the agent",
    getArgumentCompletions: async (prefix) => {
      const recent = await topRecent(process.cwd());
      const items = recent
        .map((candidate) => ({
          value: candidate.rel,
          label: `${candidate.rel}  (${formatRelDate(candidate.mtimeMs)})`,
        }))
        .filter((item) => item.value.startsWith(prefix));
      return items.length > 0 ? items : null;
    },
    handler: async (args, ctx) => {
      await handleDocReview(args, ctx, pi);
    },
  });
}
