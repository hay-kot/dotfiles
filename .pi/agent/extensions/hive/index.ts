import { spawn, type ChildProcess } from "node:child_process";

import { Type } from "typebox";

import type {
  ExtensionAPI,
  ExtensionCommandContext,
  ExtensionContext,
  ExecResult,
} from "@earendil-works/pi-coding-agent";

interface HiveSessionInfo {
  id: string;
  name?: string;
  repository?: string;
  inbox?: string;
  path?: string;
  state?: string;
}

interface HiveMessage {
  id?: string;
  topic?: string;
  sender?: string;
  payload?: string;
  created_at?: string;
  createdAt?: string;
  [key: string]: unknown;
}

interface HoneycombItem {
  id: string;
  type: "epic" | "task";
  title: string;
  desc?: string;
  status?: string;
  epic_id?: string;
  parent_id?: string;
  session_id?: string;
  depth?: number;
  [key: string]: unknown;
}

type JsonObject = Record<string, unknown>;

const HIVE_TIMEOUT_MS = 15_000;
const INBOX_LISTENER_TIMEOUT = "24h";
const INBOX_BATCH_MS = 250;
const ACTIVE_TASK_TITLE_MAX = 48;

interface InboxListenerState {
  proc: ChildProcess;
  cwd: string;
  session: HiveSessionInfo | null;
  stopped: boolean;
  alive: boolean;
  buffer: string;
  pendingMessages: HiveMessage[];
  flushTimer?: ReturnType<typeof setTimeout>;
}

interface ActiveHiveTask {
  id: string;
  type?: "epic" | "task";
  title?: string;
}

function parseJsonLines<T>(stdout: string): T[] {
  return stdout
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => JSON.parse(line) as T);
}

function formatCommandError(result: ExecResult): string {
  const output = result.stderr.trim() || result.stdout.trim();
  return output || `hive exited with code ${result.code}`;
}

async function runHive(
  pi: ExtensionAPI,
  args: string[],
  ctx: ExtensionContext,
): Promise<ExecResult> {
  return pi.exec("hive", args, {
    cwd: ctx.cwd,
    timeout: HIVE_TIMEOUT_MS,
    signal: ctx.signal,
  });
}

async function getSessionInfo(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
): Promise<HiveSessionInfo | null> {
  const result = await runHive(pi, ["session", "info", "--json"], ctx);
  if (result.code !== 0) return null;
  return JSON.parse(result.stdout.trim()) as HiveSessionInfo;
}

function buildInboxPrompt(
  session: HiveSessionInfo | null,
  messages: HiveMessage[],
  acknowledged: boolean,
): string {
  const header = session
    ? `Hive session: ${session.id}${session.inbox ? ` (${session.inbox})` : ""}`
    : "Hive session: unavailable";

  return [
    "Hive inbox messages were retrieved.",
    acknowledged
      ? "These messages were acknowledged with `hive msg inbox --ack`."
      : "These messages were not acknowledged.",
    "",
    header,
    "",
    "Messages:",
    "",
    "```json",
    JSON.stringify(messages, null, 2),
    "```",
    "",
    "Read the messages, summarize what matters, and incorporate any actionable context into this session.",
  ].join("\n");
}

function itemLabel(item: HoneycombItem): string {
  const status = item.status ?? "unknown";
  const assignee = item.session_id ? ` @${item.session_id}` : "";
  const indent = "  ".repeat(Math.max(0, item.depth ?? 0));
  const marker = item.type === "epic" ? "◆" : "•";
  return `${indent}${item.id} ${marker} ${item.type} [${status}] ${item.title}${assignee}`;
}

function idFromItemLabel(label: string): string {
  return label.trim().split(/\s+/, 1)[0] ?? "";
}

async function loadTaskContext(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  taskID: string,
): Promise<{
  show: JsonObject[];
  epicContext: string | null;
}> {
  const showResult = await runHive(pi, ["hc", "show", taskID, "--json"], ctx);
  if (showResult.code !== 0) {
    throw new Error(formatCommandError(showResult));
  }

  const show = parseJsonLines<JsonObject>(showResult.stdout);
  const item = show.find((entry) => entry.id === taskID) as
    | HoneycombItem
    | undefined;
  const epicID = item?.type === "epic" ? item.id : item?.epic_id;
  if (!epicID) {
    return { show, epicContext: null };
  }

  const contextResult = await runHive(pi, ["hc", "context", epicID], ctx);
  if (contextResult.code !== 0) {
    return { show, epicContext: null };
  }

  return { show, epicContext: contextResult.stdout.trim() || null };
}

function getItemFromShow(
  taskID: string,
  show: JsonObject[],
): HoneycombItem | undefined {
  return show.find((entry) => entry.id === taskID) as HoneycombItem | undefined;
}

function activeTaskFromShow(
  taskID: string,
  show: JsonObject[],
): ActiveHiveTask {
  const item = getItemFromShow(taskID, show);
  return {
    id: taskID,
    type: item?.type,
    title: item?.title,
  };
}

function buildTaskPrompt(
  taskID: string,
  show: JsonObject[],
  epicContext: string | null,
): string {
  const item = getItemFromShow(taskID, show);
  const itemType = item?.type ?? "item";

  return [
    `Use Hive Honeycomb ${itemType} \`${taskID}\` as the current work context.`,
    "",
    ...(epicContext ? ["Epic context:", "", epicContext, ""] : []),
    "Task details and comments:",
    "",
    "```json",
    JSON.stringify(show, null, 2),
    "```",
    "",
    "Summarize the selected Honeycomb item, identify the next concrete step, and wait for my instruction before implementing unless I explicitly asked you to start.",
  ].join("\n");
}

async function handleInbox(
  pi: ExtensionAPI,
  args: string,
  ctx: ExtensionCommandContext,
) {
  const tokens = args.trim().split(/\s+/).filter(Boolean);
  const acknowledge = tokens.includes("ack") || tokens.includes("--ack");
  const all = tokens.includes("all") || tokens.includes("--all");
  const tailIndex = tokens.findIndex(
    (token) => token === "tail" || token === "--tail" || token === "-n",
  );

  const hiveArgs = ["msg", "inbox"];
  if (acknowledge) hiveArgs.push("--ack");
  if (all) hiveArgs.push("--all");
  if (tailIndex >= 0 && tokens[tailIndex + 1])
    hiveArgs.push("--tail", tokens[tailIndex + 1]);

  const session = await getSessionInfo(pi, ctx);
  const result = await runHive(pi, hiveArgs, ctx);
  if (result.code !== 0) {
    ctx.ui.notify(`Hive inbox failed: ${formatCommandError(result)}`, "error");
    return;
  }

  let messages: HiveMessage[];
  try {
    messages = parseJsonLines<HiveMessage>(result.stdout);
  } catch (error) {
    ctx.ui.notify(
      `Could not parse hive inbox output: ${(error as Error).message}`,
      "error",
    );
    return;
  }

  if (messages.length === 0) {
    ctx.ui.notify(
      all
        ? "Hive inbox has no messages."
        : "Hive inbox has no unread messages.",
      "info",
    );
    return;
  }

  ctx.ui.notify(
    `Loaded ${messages.length} Hive inbox message${messages.length === 1 ? "" : "s"}.`,
    "info",
  );
  await pi.sendUserMessage(buildInboxPrompt(session, messages, acknowledge));
}

async function pickTask(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
): Promise<string | null> {
  const result = await runHive(pi, ["hc", "list", "--json"], ctx);
  if (result.code !== 0) {
    ctx.ui.notify(
      `Hive task list failed: ${formatCommandError(result)}`,
      "error",
    );
    return null;
  }

  let items: HoneycombItem[];
  try {
    items = parseJsonLines<HoneycombItem>(result.stdout);
  } catch (error) {
    ctx.ui.notify(
      `Could not parse hive hc list output: ${(error as Error).message}`,
      "error",
    );
    return null;
  }

  if (items.length === 0) {
    ctx.ui.notify("No open Honeycomb items found for this repository.", "info");
    return null;
  }

  const labels = items.map(itemLabel);
  const selected = await ctx.ui.select("Select Honeycomb item", labels);
  return selected ? idFromItemLabel(selected) : null;
}

async function handleTask(
  pi: ExtensionAPI,
  args: string,
  ctx: ExtensionCommandContext,
  setActiveTask: (task: ActiveHiveTask | null) => void,
) {
  if (args.trim() === "clear") {
    setActiveTask(null);
    setActiveTaskIndicator(ctx, null);
    ctx.ui.notify("Cleared active Hive task.", "info");
    return;
  }

  const taskID = args.trim() || (await pickTask(pi, ctx));
  if (!taskID) return;

  let context;
  try {
    context = await loadTaskContext(pi, ctx, taskID);
  } catch (error) {
    ctx.ui.notify(
      `Could not load ${taskID}: ${(error as Error).message}`,
      "error",
    );
    return;
  }

  const activeTask = activeTaskFromShow(taskID, context.show);
  setActiveTask(activeTask);
  setActiveTaskIndicator(ctx, activeTask);

  pi.sendMessage({
    customType: "hive-task-context",
    content: buildTaskPrompt(taskID, context.show, context.epicContext),
    display: true,
  });
  ctx.ui.notify(`Loaded ${taskID} into context.`, "info");
}

function isInboxMessage(value: unknown): value is HiveMessage {
  if (!value || typeof value !== "object") return false;
  const message = value as HiveMessage;
  return Boolean(message.id || message.topic || message.payload);
}

function queueInboxMessage(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  listener: InboxListenerState,
  message: HiveMessage,
) {
  listener.pendingMessages.push(message);
  if (listener.flushTimer) return;

  listener.flushTimer = setTimeout(() => {
    listener.flushTimer = undefined;
    const messages = listener.pendingMessages.splice(0);
    if (messages.length === 0) return;

    pi.sendUserMessage(buildInboxPrompt(listener.session, messages, true), {
      deliverAs: "followUp",
    });
    ctx.ui.notify(
      `Hive inbox listener loaded ${messages.length} message${messages.length === 1 ? "" : "s"}.`,
      "info",
    );
  }, INBOX_BATCH_MS);
}

function handleListenerStdout(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  listener: InboxListenerState,
  chunk: Buffer,
) {
  listener.buffer += chunk.toString("utf8");
  const lines = listener.buffer.split("\n");
  listener.buffer = lines.pop() ?? "";

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;

    try {
      const parsed = JSON.parse(trimmed) as unknown;
      if (isInboxMessage(parsed)) {
        queueInboxMessage(pi, ctx, listener, parsed);
      }
    } catch (error) {
      ctx.ui.notify(
        `Hive inbox listener could not parse message: ${(error as Error).message}`,
        "warning",
      );
    }
  }
}

function truncateText(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  return `${text.slice(0, Math.max(0, maxLength - 1))}…`;
}

function activeTaskParts(task: ActiveHiveTask): {
  icon: string;
  id: string;
  title: string;
} {
  return {
    icon: "󱃎",
    id: task.id,
    title: task.title ? truncateText(task.title, ACTIVE_TASK_TITLE_MAX) : "",
  };
}

function activeTaskLabel(task: ActiveHiveTask): string {
  const parts = activeTaskParts(task);
  return `${parts.icon}  ${parts.id}${parts.title ? ` · ${parts.title}` : ""}`;
}

function setActiveTaskIndicator(
  ctx: ExtensionContext,
  activeTask: ActiveHiveTask | null,
) {
  if (!activeTask) {
    ctx.ui.setWidget("hive-active-task", undefined);
    ctx.ui.setStatus("hive-active-task", undefined);
    return;
  }

  const parts = activeTaskParts(activeTask);
  const label = activeTaskLabel(activeTask);
  ctx.ui.setWidget("hive-active-task", (_tui, theme) => {
    const line =
      " " +
      theme.fg("accent", parts.icon) +
      "  " +
      theme.fg("accent", parts.id) +
      (parts.title ? theme.fg("dim", ` · ${parts.title}`) : "");
    return {
      render: () => [line],
      invalidate: () => {},
    };
  });
  ctx.ui.setStatus("hive-active-task", ctx.ui.theme.fg("accent", label));
}

function setInboxListenerIndicator(ctx: ExtensionContext, active: boolean) {
  if (active) {
    ctx.ui.setWidget("hive-inbox", (_tui, theme) => {
      const line =
        " " + theme.fg("accent", "") + "  " + theme.fg("muted", "inbox");
      return {
        render: () => [line],
        invalidate: () => {},
      };
    });
    ctx.ui.setStatus(
      "hive-inbox",
      ctx.ui.theme.fg("accent", "") + "  " + ctx.ui.theme.fg("muted", "inbox"),
    );
    return;
  }

  ctx.ui.setWidget("hive-inbox", undefined);
  ctx.ui.setStatus("hive-inbox", undefined);
}

function stopInboxListener(listener: InboxListenerState | null): null {
  if (!listener) return null;

  listener.stopped = true;
  listener.alive = false;
  if (listener.flushTimer) {
    clearTimeout(listener.flushTimer);
  }
  if (!listener.proc.killed) {
    listener.proc.kill("SIGTERM");
  }
  return null;
}

async function startInboxListener(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
  current: InboxListenerState | null,
  setListener: (listener: InboxListenerState | null) => void,
): Promise<InboxListenerState | null> {
  if (current?.alive) {
    ctx.ui.notify("Hive inbox listener is already running.", "info");
    return current;
  }

  const session = await getSessionInfo(pi, ctx);
  const proc = spawn(
    "hive",
    ["msg", "inbox", "--listen", "--ack", "--timeout", INBOX_LISTENER_TIMEOUT],
    { cwd: ctx.cwd, stdio: ["ignore", "pipe", "pipe"] },
  );

  const listener: InboxListenerState = {
    proc,
    cwd: ctx.cwd,
    session,
    stopped: false,
    alive: true,
    buffer: "",
    pendingMessages: [],
  };

  proc.stdout.on("data", (chunk: Buffer) => {
    handleListenerStdout(pi, ctx, listener, chunk);
  });

  proc.stderr.on("data", (chunk: Buffer) => {
    const text = chunk.toString("utf8").trim();
    if (text) {
      ctx.ui.notify(`Hive inbox listener: ${text}`, "warning");
    }
  });

  proc.on("error", (error) => {
    ctx.ui.notify(`Hive inbox listener failed: ${error.message}`, "error");
    setInboxListenerIndicator(ctx, false);
  });

  proc.on("exit", (code, signal) => {
    listener.alive = false;
    if (listener.stopped) return;

    setInboxListenerIndicator(ctx, false);
    ctx.ui.notify(
      `Hive inbox listener exited${signal ? ` (${signal})` : code !== null ? ` (${code})` : ""}; restarting.`,
      "warning",
    );

    setTimeout(() => {
      if (listener.stopped) return;
      startInboxListener(pi, ctx, null, setListener)
        .then(setListener)
        .catch((error) => {
          setListener(null);
          ctx.ui.notify(
            `Hive inbox listener restart failed: ${(error as Error).message}`,
            "error",
          );
        });
    }, 1000);
  });

  setInboxListenerIndicator(ctx, true);
  ctx.ui.notify("Hive inbox listener started.", "info");
  return listener;
}

async function resolveActiveTask(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  taskID: string,
): Promise<ActiveHiveTask> {
  const result = await runHive(pi, ["hc", "show", taskID, "--json"], ctx);
  if (result.code !== 0) {
    throw new Error(formatCommandError(result));
  }

  const show = parseJsonLines<JsonObject>(result.stdout);
  return activeTaskFromShow(taskID, show);
}

async function handleInboxListener(
  pi: ExtensionAPI,
  args: string,
  ctx: ExtensionCommandContext,
  getListener: () => InboxListenerState | null,
  setListener: (listener: InboxListenerState | null) => void,
) {
  const command = args.trim() || "start";

  if (command === "stop") {
    setListener(stopInboxListener(getListener()));
    setInboxListenerIndicator(ctx, false);
    ctx.ui.notify("Hive inbox listener stopped.", "info");
    return;
  }

  if (command === "status") {
    const listener = getListener();
    ctx.ui.notify(
      listener?.alive
        ? `Hive inbox listener is running for ${listener.cwd}.`
        : "Hive inbox listener is stopped.",
      "info",
    );
    return;
  }

  if (command === "restart") {
    setListener(stopInboxListener(getListener()));
    setListener(await startInboxListener(pi, ctx, null, setListener));
    return;
  }

  if (command !== "start") {
    ctx.ui.notify(
      "Usage: /hive:inbox-listener [start|stop|status|restart]",
      "error",
    );
    return;
  }

  setListener(await startInboxListener(pi, ctx, getListener(), setListener));
}

export default function hiveExtension(pi: ExtensionAPI) {
  let inboxListener: InboxListenerState | null = null;
  let activeTask: ActiveHiveTask | null = null;

  pi.on("session_start", (_event, ctx) => {
    setActiveTaskIndicator(ctx, activeTask);
  });

  pi.on("session_shutdown", (_event, ctx) => {
    inboxListener = stopInboxListener(inboxListener);
    setInboxListenerIndicator(ctx, false);
    setActiveTaskIndicator(ctx, null);
  });

  pi.registerCommand("hive:inbox", {
    description:
      "Load unread Hive inbox messages into the Pi context. Args: [ack] [all] [tail N]",
    handler: async (args, ctx) => {
      await handleInbox(pi, args, ctx);
    },
  });

  pi.registerCommand("hive:inbox-listener", {
    description:
      "Listen for Hive inbox messages and prompt the LLM when they arrive. Args: [start|stop|status|restart]",
    handler: async (args, ctx) => {
      await handleInboxListener(
        pi,
        args,
        ctx,
        () => inboxListener,
        (listener) => {
          inboxListener = listener;
        },
      );
    },
  });

  pi.registerTool({
    name: "set_hive_active_task",
    label: "Set Hive Active Task",
    description:
      "Set or clear the active Hive Honeycomb task shown in the Pi UI.",
    promptSnippet: "Set or clear the active Hive Honeycomb task widget",
    promptGuidelines: [
      "Use set_hive_active_task when a Hive task or epic becomes the current work item, especially after loading or selecting a Honeycomb item.",
      "Use set_hive_active_task with clear=true when work intentionally stops being associated with a Hive task.",
    ],
    parameters: Type.Object({
      task_id: Type.Optional(
        Type.String({
          description: "Hive Honeycomb task or epic id, for example hc-abc123.",
        }),
      ),
      clear: Type.Optional(
        Type.Boolean({ description: "Clear the active Hive task widget." }),
      ),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      if (params.clear) {
        activeTask = null;
        setActiveTaskIndicator(ctx, null);
        return {
          content: [{ type: "text", text: "Cleared active Hive task." }],
          details: { activeTask: null },
        };
      }

      const taskID = params.task_id?.trim();
      if (!taskID) {
        return {
          content: [
            { type: "text", text: "task_id is required unless clear=true." },
          ],
          details: {},
          isError: true,
        };
      }

      try {
        activeTask = await resolveActiveTask(pi, ctx, taskID);
      } catch (error) {
        return {
          content: [
            {
              type: "text",
              text: `Could not set active Hive task ${taskID}: ${(error as Error).message}`,
            },
          ],
          details: {},
          isError: true,
        };
      }

      setActiveTaskIndicator(ctx, activeTask);
      return {
        content: [
          { type: "text", text: `Active Hive task set to ${activeTask.id}.` },
        ],
        details: { activeTask },
      };
    },
  });

  pi.registerCommand("hive:task", {
    description:
      "Select a Hive Honeycomb task or epic and load it into the Pi context. Args: [item-id]",
    getArgumentCompletions: async (prefix) => {
      const result = await pi.exec("hive", ["hc", "list", "--json"], {
        timeout: HIVE_TIMEOUT_MS,
      });
      if (result.code !== 0) return null;
      try {
        const items = parseJsonLines<HoneycombItem>(result.stdout);
        const completions = items
          .filter((item) => item.id.startsWith(prefix))
          .map((item) => ({
            value: item.id,
            label: `${item.id} ${item.type} ${item.title}`,
          }));
        return completions.length > 0 ? completions : null;
      } catch {
        return null;
      }
    },
    handler: async (args, ctx) => {
      await handleTask(pi, args, ctx, (task) => {
        activeTask = task;
      });
    },
  });
}
