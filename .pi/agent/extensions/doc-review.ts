/**
 * /doc-review — gate a markdown doc in .hive/ through plannotator and feed the
 * result back to the agent for revision.
 *
 * Usage:
 *   /doc-review                    Open a picker of the 5 most recently edited
 *                                  .md files under .hive/ (recursive).
 *   /doc-review <path>             Review a specific file. Tab-completion
 *                                  suggests the same top-5 list.
 *
 * Path resolution for the argument form (in order):
 *   1. Absolute path as-is
 *   2. <cwd>/<arg>
 *   3. <cwd>/.hive/<arg>
 */

import { promises as fs } from "node:fs";
import * as path from "node:path";
import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

const HIVE_DIR = ".hive";
const TOP_N = 5;

type Candidate = { abs: string; rel: string; mtimeMs: number };

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
						out.push({ abs: full, rel: path.relative(root, full), mtimeMs: stat.mtimeMs });
					}
				} catch {
					// dangling symlink, ignore
				}
				continue;
			}
			if (entry.isDirectory()) {
				await walk(full);
			} else if (entry.isFile() && entry.name.endsWith(".md")) {
				try {
					const stat = await fs.stat(full);
					out.push({ abs: full, rel: path.relative(root, full), mtimeMs: stat.mtimeMs });
				} catch {
					// unreadable, ignore
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

async function resolveArg(cwd: string, arg: string): Promise<string | null> {
	const candidates = path.isAbsolute(arg)
		? [arg]
		: [path.join(cwd, arg), path.join(cwd, HIVE_DIR, arg)];
	for (const c of candidates) {
		try {
			const stat = await fs.stat(c);
			if (stat.isFile()) return c;
		} catch {
			// keep trying
		}
	}
	return null;
}

function formatRelDate(ms: number): string {
	const diff = Date.now() - ms;
	const m = Math.floor(diff / 60_000);
	if (m < 1) return "just now";
	if (m < 60) return `${m}m ago`;
	const h = Math.floor(m / 60);
	if (h < 24) return `${h}h ago`;
	const d = Math.floor(h / 24);
	return `${d}d ago`;
}

export default function docReviewExtension(pi: ExtensionAPI) {
	pi.registerCommand("review-doc", {
		description: "Gate a .hive/ doc through plannotator and revise via the agent",
		getArgumentCompletions: async (prefix) => {
			const recent = await topRecent(process.cwd());
			const items = recent
				.map((c) => ({ value: c.rel, label: `${c.rel}  (${formatRelDate(c.mtimeMs)})` }))
				.filter((i) => i.value.startsWith(prefix));
			return items.length > 0 ? items : null;
		},
		handler: async (args: string, ctx: ExtensionCommandContext) => {
			const trimmed = args.trim();
			let target: string | null = null;

			if (trimmed) {
				target = await resolveArg(ctx.cwd, trimmed);
				if (!target) {
					ctx.ui.notify(`File not found: ${trimmed}`, "error");
					return;
				}
			} else {
				const recent = await topRecent(ctx.cwd);
				if (recent.length === 0) {
					ctx.ui.notify(`No .md files found under ${HIVE_DIR}/`, "warning");
					return;
				}
				const labels = recent.map((c) => `${c.rel}  (${formatRelDate(c.mtimeMs)})`);
				const picked = await ctx.ui.select("Doc to review", labels);
				if (!picked) return;
				const idx = labels.indexOf(picked);
				target = recent[idx].abs;
			}

			const relForDisplay = path.relative(ctx.cwd, target) || target;
			ctx.ui.setStatus("doc-review", `plannotator gate: ${relForDisplay}`);

			let stdout = "";
			let stderr = "";
			let code = 0;
			try {
				const result = await pi.exec("plannotator", ["annotate", target, "--gate", "--json"], {
					signal: ctx.signal,
				});
				stdout = result.stdout;
				stderr = result.stderr;
				code = result.code;
			} catch (err) {
				ctx.ui.setStatus("doc-review", "");
				ctx.ui.notify(`plannotator failed to launch: ${(err as Error).message}`, "error");
				return;
			} finally {
				ctx.ui.setStatus("doc-review", "");
			}

			const feedback = stdout.trim() || stderr.trim() || "(no output from plannotator)";

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
		},
	});
}
