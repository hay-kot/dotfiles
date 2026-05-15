/**
 * Timer — schedule a one-off delayed prompt.
 *
 * Command:
 *   /timer <delay> <prompt>      — run prompt after delay
 *   /timer list                  — show pending timers
 *   /timer stop [id]             — cancel one or all timers
 *
 * Tools:
 *   set_timer    — LLM can schedule a delayed prompt
 *   cancel_timer — LLM can cancel a pending timer
 *
 * Delays: Ns, Nm, Nh, Nd (e.g. 10m, 30s, 2h, 1d). Minimum 5s.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const MIN_DELAY_MS = 5_000;
const MAX_DELAY_MS = 24 * 60 * 60 * 1000; // 24h

interface TimerEntry {
	id: string;
	prompt: string;
	delayMs: number;
	createdAt: Date;
	firesAt: Date;
	timer: ReturnType<typeof setTimeout>;
}

function parseDelayToken(token: string): number | null {
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

function fmtTime(date: Date): string {
	return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
}

export default function (pi: ExtensionAPI) {
	const timers = new Map<string, TimerEntry>();
	let nextId = 1;

	function cancelTimer(entry: TimerEntry) {
		clearTimeout(entry.timer);
		timers.delete(entry.id);
	}

	function cancelAll(): number {
		const count = timers.size;
		for (const entry of timers.values()) cancelTimer(entry);
		return count;
	}

	function listTimers(): string {
		if (timers.size === 0) return "No pending timers.";
		const lines = [...timers.values()].map(
			(e) => `• ${e.id}  fires at ${fmtTime(e.firesAt)} (in ${fmtMs(e.firesAt.getTime() - Date.now())})  prompt: "${e.prompt}"`,
		);
		return `Pending timers (${timers.size}):\n${lines.join("\n")}`;
	}

	function scheduleTimer(delayMs: number, prompt: string, ctx: { isIdle: () => boolean }): { id: string; firesAt: Date } {
		const effectiveMs = Math.min(Math.max(delayMs, MIN_DELAY_MS), MAX_DELAY_MS);
		const id = `timer-${nextId++}`;
		const now = new Date();
		const firesAt = new Date(now.getTime() + effectiveMs);

		const timer = setTimeout(() => {
			timers.delete(id);
			if (!ctx.isIdle()) {
				pi.sendUserMessage(prompt, { deliverAs: "followUp" });
			} else {
				pi.sendUserMessage(prompt);
			}
		}, effectiveMs);

		timers.set(id, { id, prompt, delayMs: effectiveMs, createdAt: now, firesAt, timer });
		return { id, firesAt };
	}

	// ── Command ──────────────────────────────────────────────────────────
	pi.registerCommand("timer", {
		description: "Schedule a one-off delayed prompt. Usage: /timer <delay> <prompt>",
		handler: async (args, ctx) => {
			const trimmed = args.trim();

			if (!trimmed || trimmed === "help") {
				ctx.ui.notify(
					"Usage: /timer <delay> <prompt>\n\nSubcommands: list, stop [id]\nDelays: Ns, Nm, Nh, Nd (min: 5s, max: 24h)",
					"info",
				);
				return;
			}

			if (trimmed === "list") {
				ctx.ui.notify(listTimers(), "info");
				return;
			}

			if (trimmed === "stop") {
				const count = cancelAll();
				ctx.ui.notify(count > 0 ? `Cancelled ${count} timer(s).` : "No pending timers.", "info");
				return;
			}

			if (trimmed.startsWith("stop ")) {
				const id = trimmed.slice(5).trim();
				const entry = timers.get(id);
				if (!entry) {
					ctx.ui.notify(`No timer "${id}". Use /timer list.`, "warning");
					return;
				}
				cancelTimer(entry);
				ctx.ui.notify(`Timer "${id}" cancelled.`, "info");
				return;
			}

			// Parse: <delay> <prompt>
			const parts = trimmed.split(/\s+/);
			const delayMs = parseDelayToken(parts[0]!);
			if (delayMs === null) {
				ctx.ui.notify("Invalid delay. Use format like 10m, 30s, 2h, 1d.", "warning");
				return;
			}

			const prompt = parts.slice(1).join(" ").trim();
			if (!prompt) {
				ctx.ui.notify("Missing prompt. Usage: /timer <delay> <prompt>", "warning");
				return;
			}

			const { id, firesAt } = scheduleTimer(delayMs, prompt, ctx);
			ctx.ui.notify(
				`Timer "${id}" set: "${prompt}" fires at ${fmtTime(firesAt)} (in ${fmtMs(Math.max(delayMs, MIN_DELAY_MS))})\nCancel: /timer stop ${id}`,
				"info",
			);
		},
	});

	// ── LLM Tools ────────────────────────────────────────────────────────
	pi.registerTool({
		name: "set_timer",
		label: "Set Timer",
		description:
			"Schedule a one-off prompt to execute after a delay. Use for deferred actions, reminders, or delayed checks.",
		promptSnippet: "Schedule a one-off delayed prompt (e.g. 10m, 2h)",
		promptGuidelines: [
			"Use set_timer to schedule a prompt that runs once after a delay. The delay format is a number followed by s/m/h/d (e.g. '10m', '2h', '30s').",
		],
		parameters: Type.Object({
			delay: Type.String({ description: 'Delay before firing, e.g. "10m", "2h", "30s", "1d"' }),
			prompt: Type.String({ description: "The prompt or command to execute after the delay" }),
		}),
		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			const delayMs = parseDelayToken(params.delay);
			if (delayMs === null) {
				return {
					content: [{ type: "text", text: `Invalid delay "${params.delay}". Use format like 10m, 30s, 2h, 1d.` }],
					details: {},
					isError: true,
				};
			}

			const { id, firesAt } = scheduleTimer(delayMs, params.prompt, ctx);
			return {
				content: [
					{
						type: "text",
						text: `Timer "${id}" scheduled: "${params.prompt}" fires at ${fmtTime(firesAt)} (in ${fmtMs(Math.max(delayMs, MIN_DELAY_MS))})`,
					},
				],
				details: { id, firesAt: firesAt.toISOString(), prompt: params.prompt },
			};
		},
	});

	pi.registerTool({
		name: "cancel_timer",
		label: "Cancel Timer",
		description: "Cancel a pending timer. Use when a scheduled action is no longer needed.",
		promptSnippet: "Cancel a pending /timer by ID, or cancel all timers",
		promptGuidelines: [
			"Use cancel_timer to stop a pending /timer when it is no longer needed.",
		],
		parameters: Type.Object({
			id: Type.Optional(
				Type.String({ description: 'Timer ID to cancel (e.g. "timer-1"). Omit to cancel all timers.' }),
			),
		}),
		async execute(_toolCallId, params) {
			if (params.id) {
				const entry = timers.get(params.id);
				if (!entry) {
					return {
						content: [{ type: "text", text: `No pending timer "${params.id}". ${listTimers()}` }],
						details: {},
					};
				}
				cancelTimer(entry);
				return {
					content: [{ type: "text", text: `Timer "${params.id}" cancelled.` }],
					details: { cancelled: params.id },
				};
			}

			const count = cancelAll();
			return {
				content: [{ type: "text", text: count > 0 ? `Cancelled ${count} timer(s).` : "No pending timers." }],
				details: { cancelledCount: count },
			};
		},
	});

	pi.on("session_shutdown", () => {
		cancelAll();
	});
}
