/**
 * /time:* — delayed and recurring prompt scheduling.
 *
 * Commands:
 *   /time:timer <delay> <prompt>       — run prompt once after delay
 *   /time:timer list                   — show pending timers
 *   /time:timer stop [id]              — cancel one or all timers
 *   /time:loop [interval] <prompt>     — run prompt on a recurring interval
 *   /time:loop list                    — show active loops
 *   /time:loop stop [id]               — cancel one or all loops
 *
 * Tools:
 *   set_timer, cancel_timer, cancel_loop
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const DEFAULT_LOOP_INTERVAL = "10m";
const MIN_LOOP_INTERVAL_MS = 10_000;
const MAX_LOOP_AGE_MS = 7 * 24 * 60 * 60 * 1000;
const MIN_TIMER_DELAY_MS = 5_000;
const MAX_TIMER_DELAY_MS = 24 * 60 * 60 * 1000;

interface LoopEntry {
  id: string;
  prompt: string;
  intervalMs: number;
  createdAt: Date;
  fireCount: number;
  timer: ReturnType<typeof setInterval>;
  expiryTimer: ReturnType<typeof setTimeout>;
}

interface TimerEntry {
  id: string;
  prompt: string;
  delayMs: number;
  createdAt: Date;
  firesAt: Date;
  timer: ReturnType<typeof setTimeout>;
}

function parseDurationToken(token: string): number | null {
  const match = token.match(/^(\d+(?:\.\d+)?)(s|m|h|d)$/i);
  if (!match) return null;

  const value = parseFloat(match[1]!);
  switch (match[2]!.toLowerCase()) {
    case "s":
      return value * 1_000;
    case "m":
      return value * 60_000;
    case "h":
      return value * 3_600_000;
    case "d":
      return value * 86_400_000;
    default:
      return null;
  }
}

function fmtMs(ms: number): string {
  if (ms < 60_000) return `${Math.round(ms / 1_000)}s`;
  if (ms < 3_600_000) return `${Math.round(ms / 60_000)}m`;
  if (ms < 86_400_000) return `${Math.round(ms / 3_600_000)}h`;
  return `${Math.round(ms / 86_400_000)}d`;
}

function fmtTime(date: Date): string {
  return date.toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

function parseLoopArgs(
  input: string,
): { intervalMs: number; prompt: string } | null {
  const trimmed = input.trim();
  if (!trimmed) return null;

  const parts = trimmed.split(/\s+/);
  const leadingMs = parseDurationToken(parts[0]!);
  if (leadingMs !== null) {
    return { intervalMs: leadingMs, prompt: parts.slice(1).join(" ").trim() };
  }

  const trailing = trimmed.match(
    /^([\s\S]+?)\s+every\s+(\d+(?:\.\d+)?)(s|m|h|d)$/i,
  );
  if (trailing) {
    const ms = parseDurationToken(
      `${trailing[2]}${trailing[3]!.toLowerCase()}`,
    );
    if (ms) return { intervalMs: ms, prompt: trailing[1]!.trim() };
  }

  return {
    intervalMs: parseDurationToken(DEFAULT_LOOP_INTERVAL)!,
    prompt: trimmed,
  };
}

export default function timeExtension(pi: ExtensionAPI) {
  const loops = new Map<string, LoopEntry>();
  const timers = new Map<string, TimerEntry>();
  let nextLoopId = 1;
  let nextTimerId = 1;

  function sendPrompt(prompt: string, ctx: { isIdle: () => boolean }) {
    if (!ctx.isIdle()) {
      pi.sendUserMessage(prompt, { deliverAs: "followUp" });
      return;
    }

    pi.sendUserMessage(prompt);
  }

  function cancelLoop(entry: LoopEntry) {
    clearInterval(entry.timer);
    clearTimeout(entry.expiryTimer);
    loops.delete(entry.id);
  }

  function cancelAllLoops(): number {
    const count = loops.size;
    for (const entry of loops.values()) cancelLoop(entry);
    return count;
  }

  function listLoops(): string {
    if (loops.size === 0) return "No active loops.";
    const lines = [...loops.values()].map(
      (entry) =>
        `• ${entry.id}  every ${fmtMs(entry.intervalMs)}  fires: ${entry.fireCount}  prompt: "${entry.prompt}"`,
    );
    return `Active loops (${loops.size}):\n${lines.join("\n")}`;
  }

  function cancelTimer(entry: TimerEntry) {
    clearTimeout(entry.timer);
    timers.delete(entry.id);
  }

  function cancelAllTimers(): number {
    const count = timers.size;
    for (const entry of timers.values()) cancelTimer(entry);
    return count;
  }

  function listTimers(): string {
    if (timers.size === 0) return "No pending timers.";
    const lines = [...timers.values()].map(
      (entry) =>
        `• ${entry.id}  fires at ${fmtTime(entry.firesAt)} (in ${fmtMs(entry.firesAt.getTime() - Date.now())})  prompt: "${entry.prompt}"`,
    );
    return `Pending timers (${timers.size}):\n${lines.join("\n")}`;
  }

  function scheduleTimer(
    delayMs: number,
    prompt: string,
    ctx: { isIdle: () => boolean },
  ): { id: string; firesAt: Date; effectiveMs: number } {
    const effectiveMs = Math.min(
      Math.max(delayMs, MIN_TIMER_DELAY_MS),
      MAX_TIMER_DELAY_MS,
    );
    const id = `timer-${nextTimerId++}`;
    const now = new Date();
    const firesAt = new Date(now.getTime() + effectiveMs);

    const timer = setTimeout(() => {
      timers.delete(id);
      sendPrompt(prompt, ctx);
    }, effectiveMs);

    timers.set(id, {
      id,
      prompt,
      delayMs: effectiveMs,
      createdAt: now,
      firesAt,
      timer,
    });
    return { id, firesAt, effectiveMs };
  }

  pi.registerCommand("time:loop", {
    description: `Run a prompt on a recurring interval. Usage: /time:loop [interval] <prompt> (default: ${DEFAULT_LOOP_INTERVAL})`,
    handler: async (args, ctx) => {
      const trimmed = args.trim();

      if (!trimmed || trimmed === "help") {
        ctx.ui.notify(
          `Usage: /time:loop [interval] <prompt>\n\nSubcommands: list, stop [id]\nIntervals: Ns, Nm, Nh, Nd (default: ${DEFAULT_LOOP_INTERVAL}, min: 10s)`,
          "info",
        );
        return;
      }

      if (trimmed === "list") {
        ctx.ui.notify(listLoops(), "info");
        return;
      }

      if (trimmed === "stop") {
        const count = cancelAllLoops();
        ctx.ui.notify(
          count > 0 ? `Cancelled ${count} loop(s).` : "No active loops.",
          "info",
        );
        return;
      }

      if (trimmed.startsWith("stop ")) {
        const id = trimmed.slice(5).trim();
        const entry = loops.get(id);
        if (!entry) {
          ctx.ui.notify(`No loop "${id}". Use /time:loop list.`, "warning");
          return;
        }
        cancelLoop(entry);
        ctx.ui.notify(`Loop "${id}" cancelled.`, "info");
        return;
      }

      const parsed = parseLoopArgs(trimmed);
      if (!parsed?.prompt) {
        ctx.ui.notify(
          "Missing prompt. Usage: /time:loop [interval] <prompt>",
          "warning",
        );
        return;
      }

      const effectiveMs = Math.max(parsed.intervalMs, MIN_LOOP_INTERVAL_MS);
      const id = `loop-${nextLoopId++}`;

      const sendLoopPrompt = () => {
        const entry = loops.get(id);
        if (entry) entry.fireCount++;
        sendPrompt(parsed.prompt, ctx);
      };

      const timer = setInterval(sendLoopPrompt, effectiveMs);
      const expiryTimer = setTimeout(() => {
        const entry = loops.get(id);
        if (!entry) return;
        cancelLoop(entry);
        ctx.ui.notify(
          `Loop "${id}" expired after ${fmtMs(MAX_LOOP_AGE_MS)}.`,
          "info",
        );
      }, MAX_LOOP_AGE_MS);

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
        `Loop "${id}" scheduled: "${parsed.prompt}" every ${fmtMs(effectiveMs)}\nCancel: /time:loop stop ${id}`,
        "info",
      );

      pi.sendUserMessage(parsed.prompt);
    },
  });

  pi.registerCommand("time:timer", {
    description:
      "Schedule a one-off delayed prompt. Usage: /time:timer <delay> <prompt>",
    handler: async (args, ctx) => {
      const trimmed = args.trim();

      if (!trimmed || trimmed === "help") {
        ctx.ui.notify(
          "Usage: /time:timer <delay> <prompt>\n\nSubcommands: list, stop [id]\nDelays: Ns, Nm, Nh, Nd (min: 5s, max: 24h)",
          "info",
        );
        return;
      }

      if (trimmed === "list") {
        ctx.ui.notify(listTimers(), "info");
        return;
      }

      if (trimmed === "stop") {
        const count = cancelAllTimers();
        ctx.ui.notify(
          count > 0 ? `Cancelled ${count} timer(s).` : "No pending timers.",
          "info",
        );
        return;
      }

      if (trimmed.startsWith("stop ")) {
        const id = trimmed.slice(5).trim();
        const entry = timers.get(id);
        if (!entry) {
          ctx.ui.notify(`No timer "${id}". Use /time:timer list.`, "warning");
          return;
        }
        cancelTimer(entry);
        ctx.ui.notify(`Timer "${id}" cancelled.`, "info");
        return;
      }

      const parts = trimmed.split(/\s+/);
      const delayMs = parseDurationToken(parts[0]!);
      if (delayMs === null) {
        ctx.ui.notify(
          "Invalid delay. Use format like 10m, 30s, 2h, 1d.",
          "warning",
        );
        return;
      }

      const prompt = parts.slice(1).join(" ").trim();
      if (!prompt) {
        ctx.ui.notify(
          "Missing prompt. Usage: /time:timer <delay> <prompt>",
          "warning",
        );
        return;
      }

      const { id, firesAt, effectiveMs } = scheduleTimer(delayMs, prompt, ctx);
      ctx.ui.notify(
        `Timer "${id}" set: "${prompt}" fires at ${fmtTime(firesAt)} (in ${fmtMs(effectiveMs)})\nCancel: /time:timer stop ${id}`,
        "info",
      );
    },
  });

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
      delay: Type.String({
        description: 'Delay before firing, e.g. "10m", "2h", "30s", "1d"',
      }),
      prompt: Type.String({
        description: "The prompt or command to execute after the delay",
      }),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const delayMs = parseDurationToken(params.delay);
      if (delayMs === null) {
        return {
          content: [
            {
              type: "text",
              text: `Invalid delay "${params.delay}". Use format like 10m, 30s, 2h, 1d.`,
            },
          ],
          details: {},
          isError: true,
        };
      }

      const { id, firesAt, effectiveMs } = scheduleTimer(
        delayMs,
        params.prompt,
        ctx,
      );
      return {
        content: [
          {
            type: "text",
            text: `Timer "${id}" scheduled: "${params.prompt}" fires at ${fmtTime(firesAt)} (in ${fmtMs(effectiveMs)})`,
          },
        ],
        details: { id, firesAt: firesAt.toISOString(), prompt: params.prompt },
      };
    },
  });

  pi.registerTool({
    name: "cancel_timer",
    label: "Cancel Timer",
    description:
      "Cancel a pending timer. Use when a scheduled action is no longer needed.",
    promptSnippet: "Cancel a pending /time:timer by ID, or cancel all timers",
    promptGuidelines: [
      "Use cancel_timer to stop a pending /time:timer when it is no longer needed.",
    ],
    parameters: Type.Object({
      id: Type.Optional(
        Type.String({
          description:
            'Timer ID to cancel (e.g. "timer-1"). Omit to cancel all timers.',
        }),
      ),
    }),
    async execute(_toolCallId, params) {
      if (params.id) {
        const entry = timers.get(params.id);
        if (!entry) {
          return {
            content: [
              {
                type: "text",
                text: `No pending timer "${params.id}". ${listTimers()}`,
              },
            ],
            details: { cancelled: null as string | null, cancelledCount: 0 },
          };
        }
        cancelTimer(entry);
        return {
          content: [{ type: "text", text: `Timer "${params.id}" cancelled.` }],
          details: { cancelled: params.id, cancelledCount: 1 },
        };
      }

      const count = cancelAllTimers();
      return {
        content: [
          {
            type: "text",
            text:
              count > 0 ? `Cancelled ${count} timer(s).` : "No pending timers.",
          },
        ],
        details: { cancelled: null as string | null, cancelledCount: count },
      };
    },
  });

  pi.registerTool({
    name: "cancel_loop",
    label: "Cancel Loop",
    description:
      "Cancel an active recurring loop. Use when the monitored task is complete or no longer needed.",
    promptSnippet:
      "Cancel a recurring /time:loop by ID, or cancel all active loops",
    promptGuidelines: [
      "Use cancel_loop to stop a recurring /time:loop when the task it monitors is complete or no longer needed.",
    ],
    parameters: Type.Object({
      id: Type.Optional(
        Type.String({
          description:
            'Loop ID to cancel (e.g. "loop-1"). Omit to cancel all active loops.',
        }),
      ),
    }),
    async execute(_toolCallId, params) {
      if (params.id) {
        const entry = loops.get(params.id);
        if (!entry) {
          return {
            content: [
              {
                type: "text",
                text: `No active loop with ID "${params.id}". ${listLoops()}`,
              },
            ],
            details: { cancelled: null as string | null, cancelledCount: 0 },
          };
        }
        cancelLoop(entry);
        return {
          content: [{ type: "text", text: `Loop "${params.id}" cancelled.` }],
          details: { cancelled: params.id, cancelledCount: 1 },
        };
      }

      const count = cancelAllLoops();
      return {
        content: [
          {
            type: "text",
            text:
              count > 0 ? `Cancelled ${count} loop(s).` : "No active loops.",
          },
        ],
        details: { cancelled: null as string | null, cancelledCount: count },
      };
    },
  });

  pi.on("session_shutdown", () => {
    cancelAllTimers();
    cancelAllLoops();
  });
}
