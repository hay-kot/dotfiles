/**
 * /review-tuicr — Interactive code review via tuicr running inline.
 *
 * Temporarily suspends pi's TUI, runs tuicr with inherited stdio so it takes
 * over the terminal, then restores pi when tuicr exits.
 *
 * Usage:
 *   /review-tuicr                     Review uncommitted changes in cwd.
 *   /review-tuicr main..HEAD          Review a revision range.
 *   /review-tuicr /path/to/repo       Review a different directory.
 *   /review-tuicr main..HEAD /path    Revision range + directory.
 *
 * Also registers a `review_changes` tool the LLM can call directly.
 */

import { Type } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync, spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { resolve } from "node:path";

// ── helpers ──────────────────────────────────────────────────────────

let tuiInstance: { stop(): void; start(): void; requestRender(force?: boolean): void } | undefined;

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
		throw new Error("TUI instance not captured yet. Try again after the UI has rendered.");
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

// ── extension ────────────────────────────────────────────────────────

export default function tuicrExtension(pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		if (tuiInstance) return;
		ctx.ui.setWidget("__tuicr-tui-capture", (tui: unknown) => {
			tuiInstance = tui as typeof tuiInstance;
			setTimeout(() => ctx.ui.setWidget("__tuicr-tui-capture", undefined), 0);
			return { render: () => [], dispose: () => {} };
		});
	});

	// ── /review-tuicr command ────────────────────────────────────────

	pi.registerCommand("review-tuicr", {
		description: "Launch tuicr to interactively review code changes",
		handler: async (args, ctx) => {
			const parts = (args ?? "").trim().split(/\s+/).filter(Boolean);
			let dir = ctx.cwd;
			let revisions: string | undefined;

			for (const part of parts) {
				const resolved = resolve(ctx.cwd, part);
				if (existsSync(resolved) && isGitRepo(resolved)) {
					dir = resolved;
				} else {
					revisions = part;
				}
			}

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
			} catch (err) {
				ctx.ui.notify(`tuicr failed: ${err}`, "error");
			}
		},
	});

	// ── review_changes tool ──────────────────────────────────────────

	pi.registerTool({
		name: "review_changes",
		label: "Review Changes",
		description:
			"Launch tuicr so the user can interactively review code changes " +
			"in a split terminal pane. Returns the user's review comments.",
		promptSnippet: "Launch interactive code review TUI for the user",
		promptGuidelines: [
			"Use review_changes when the user asks to review code, diff, or your changes interactively.",
			"Do NOT use review_changes for simple git diff viewing — only for interactive review sessions.",
		],
		parameters: Type.Object({
			directory: Type.Optional(
				Type.String({ description: "Git repo directory to review (default: cwd)" }),
			),
			revisions: Type.Optional(
				Type.String({
					description:
						"Git revision range to review, e.g. 'HEAD~3', 'main..feature'. " +
						"Default: uncommitted changes.",
				}),
			),
		}),
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const dir = params.directory ? resolve(ctx.cwd, params.directory) : ctx.cwd;

			if (!isGitRepo(dir)) {
				throw new Error(`Not a git repository: ${dir}`);
			}

			const output = runTuicrInline(dir, params.revisions);
			const parsed = parseReviewOutput(output);

			if (!parsed.hasComments) {
				return {
					content: [
						{
							type: "text",
							text:
								"The user closed the review without exporting comments. " +
								"They may paste feedback manually, or the review is complete with no issues.",
						},
					],
					details: { hasComments: false },
				};
			}

			return {
				content: [
					{
						type: "text",
						text: `The user completed their code review. Here are their comments:\n\n${parsed.text}`,
					},
				],
				details: { hasComments: true, commentCount: parsed.commentCount },
			};
		},
	});
}
