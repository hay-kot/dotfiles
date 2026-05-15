/**
 * Loop — run a prompt on a recurring interval.
 *
 * Command:
 *   /loop [interval] <prompt>    — schedule a recurring prompt (default: 10m)
 *   /loop list                   — show active loops
 *   /loop stop [id]              — cancel one or all loops
 *
 * Tool:
 *   cancel_loop — LLM can cancel a loop when the task is complete
 *
 * Intervals: Ns, Nm, Nh, Nd (e.g. 5m, 30s, 2h, 1d). Minimum 10s.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const DEFAULT_INTERVAL = "10m";
const MIN_INTERVAL_MS = 10_000;
const MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;

interface LoopEntry {
	id: string;
	prompt: string;
	intervalMs: number;
	createdAt: Date;
	fireCount: number;
	timer: ReturnType<typeof setInterval>;
	expiryTimer: ReturnType<typeof setTimeout>;
}

function parseIntervalToken(token: string): number | null {
	const m = token.match(/^(\d+(?:\.\d+)?)(s|m|h|d)$/i);
	if (!m) return null;
	const n = parseFloat(m[1]!);
	switch (m[2]!.toLowerCase()) {
		case "s": return n * 1_000;
		case "m": return n * 60_000;
		case "h": return n * 3_600_000;
		case "d": return n * 86_400_000;
		default: return null;
	}
}

function fmtMs(ms: number): string {
	if (ms < 60_000) return `${Math.round(ms / 1_000)}s`;
	if (ms < 3_600_000) return `${Math.round(ms / 60_000)}m`;
	if (ms < 86_400_000) return `${Math.round(ms / 3_600_000)}h`;
	return `${Math.round(ms / 86_400_000)}d`;
}

function parseArgs(input: string): { intervalMs: number; prompt: string } | null {
	const trimmed = input.trim();
	if (!trimmed) return null;

	// Leading token: /loop 5m check deploy
	const parts = trimmed.split(/\s+/);
	const leadingMs = parseIntervalToken(parts[0]!);
	if (leadingMs !== null) {
		return { intervalMs: leadingMs, prompt: parts.slice(1).join(" ").trim() };
	}

	// Trailing "every" clause: /loop check deploy every 5m
	const trailing = trimmed.match(/^([\s\S]+?)\s+every\s+(\d+(?:\.\d+)?)(s|m|h|d)$/i);
	if (trailing) {
		const unit = trailing[3]!.toLowerCase();
		const ms = parseIntervalToken(`${trailing[2]}${unit}`);
		if (ms) return { intervalMs: ms, prompt: trailing[1]!.trim() };
	}

	// Default interval
	return { intervalMs: parseIntervalToken(DEFAULT_INTERVAL)!, prompt: trimmed };
}

export default function (pi: ExtensionAPI) {
	const loops = new Map<string, LoopEntry>();
	let nextId = 1;

	function cancel(entry: LoopEntry) {
		clearInterval(entry.timer);
		clearTimeout(entry.expiryTimer);
		loops.delete(entry.id);
	}

	function cancelAll(): number {
		const count = loops.size;
		for (const entry of loops.values()) cancel(entry);
		return count;
	}

	function listLoops(): string {
		if (loops.size === 0) return "No active loops.";
		const lines = [...loops.values()].map(
			(e) => `• ${e.id}  every ${fmtMs(e.intervalMs)}  fires: ${e.fireCount}  prompt: "${e.prompt}"`,
		);
		return `Active loops (${loops.size}):\n${lines.join("\n")}`;
	}

	// ── Command ──────────────────────────────────────────────────────────
	pi.registerCommand("loop", {
		description: `Run a prompt on a recurring interval. Usage: /loop [interval] <prompt> (default: ${DEFAULT_INTERVAL})`,
		handler: async (args, ctx) => {
			const trimmed = args.trim();

			if (!trimmed || trimmed === "help") {
				ctx.ui.notify(
					`Usage: /loop [interval] <prompt>\n\nSubcommands: list, stop [id]\nIntervals: Ns, Nm, Nh, Nd (default: ${DEFAULT_INTERVAL}, min: 10s)`,
					"info",
				);
				return;
			}

			if (trimmed === "list") {
				ctx.ui.notify(listLoops(), "info");
				return;
			}

			if (trimmed === "stop") {
				const count = cancelAll();
				ctx.ui.notify(count > 0 ? `Cancelled ${count} loop(s).` : "No active loops.", "info");
				return;
			}

			if (trimmed.startsWith("stop ")) {
				const id = trimmed.slice(5).trim();
				const entry = loops.get(id);
				if (!entry) {
					ctx.ui.notify(`No loop "${id}". Use /loop list.`, "warning");
					return;
				}
				cancel(entry);
				ctx.ui.notify(`Loop "${id}" cancelled.`, "info");
				return;
			}

			const parsed = parseArgs(trimmed);
			if (!parsed || !parsed.prompt) {
				ctx.ui.notify("Missing prompt. Usage: /loop [interval] <prompt>", "warning");
				return;
			}

			const effectiveMs = Math.max(parsed.intervalMs, MIN_INTERVAL_MS);
			const id = `loop-${nextId++}`;

			const sendPrompt = () => {
				const entry = loops.get(id);
				if (entry) entry.fireCount++;
				if (!ctx.isIdle()) {
					pi.sendUserMessage(parsed.prompt, { deliverAs: "followUp" });
				} else {
					pi.sendUserMessage(parsed.prompt);
				}
			};

			const timer = setInterval(sendPrompt, effectiveMs);
			const expiryTimer = setTimeout(() => {
				const entry = loops.get(id);
				if (entry) {
					cancel(entry);
					ctx.ui.notify(`Loop "${id}" expired after ${fmtMs(MAX_AGE_MS)}.`, "info");
				}
			}, MAX_AGE_MS);

			loops.set(id, {
				id,
				prompt: parsed.prompt,
				intervalMs: effectiveMs,
				createdAt: new Date(),
				fireCount: 0,
				timer,
				expiryTimer,
			});

			ctx.ui.notify(
				`Loop "${id}" scheduled: "${parsed.prompt}" every ${fmtMs(effectiveMs)}\nCancel: /loop stop ${id}`,
				"info",
			);

			// Fire immediately
			pi.sendUserMessage(parsed.prompt);
		},
	});

	// ── LLM Tool ─────────────────────────────────────────────────────────
	pi.registerTool({
		name: "cancel_loop",
		label: "Cancel Loop",
		description:
			"Cancel an active recurring loop. Use when the monitored task is complete or no longer needed.",
		promptSnippet: "Cancel a recurring /loop by ID, or cancel all active loops",
		promptGuidelines: [
			"Use cancel_loop to stop a recurring /loop when the task it monitors is complete or no longer needed.",
		],
		parameters: Type.Object({
			id: Type.Optional(
				Type.String({ description: 'Loop ID to cancel (e.g. "loop-1"). Omit to cancel all loops.' }),
			),
		}),
		async execute(_toolCallId, params) {
			if (params.id) {
				const entry = loops.get(params.id);
				if (!entry) {
					return {
						content: [{ type: "text", text: `No active loop with ID "${params.id}". ${listLoops()}` }],
						details: {},
					};
				}
				cancel(entry);
				return {
					content: [{ type: "text", text: `Loop "${params.id}" cancelled.` }],
					details: { cancelled: params.id },
				};
			}

			const count = cancelAll();
			return {
				content: [{ type: "text", text: count > 0 ? `Cancelled ${count} loop(s).` : "No active loops." }],
				details: { cancelledCount: count },
			};
		},
	});

	pi.on("session_shutdown", () => {
		cancelAll();
	});
}
