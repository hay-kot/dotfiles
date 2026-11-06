import { execFileSync } from "node:child_process";
import { EventEmitter } from "node:events";
import { readFileSync, realpathSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

export function piPackageDirectory() {
  if (process.env.PI_PACKAGE_DIR) return resolve(process.env.PI_PACKAGE_DIR);
  let dir = dirname(
    realpathSync(
      execFileSync("sh", ["-c", "command -v pi"], { encoding: "utf8" }).trim(),
    ),
  );
  while (dir !== dirname(dir)) {
    try {
      if (
        JSON.parse(readFileSync(join(dir, "package.json"), "utf8")).name ===
        "@earendil-works/pi-coding-agent"
      )
        return dir;
    } catch {}
    dir = dirname(dir);
  }
  throw new Error(
    "Cannot locate Pi. Install pi or set PI_PACKAGE_DIR to its package directory.",
  );
}

export const piDirectory = piPackageDirectory();
const require = createRequire(join(piDirectory, "package.json"));
const { createJiti } = require("jiti");
const aliases = {
  "@earendil-works/pi-coding-agent": join(piDirectory, "dist/index.js"),
  "@earendil-works/pi-agent-core": join(
    dirname(piDirectory),
    "pi-agent-core/dist/index.js",
  ),
  "@earendil-works/pi-tui": join(dirname(piDirectory), "pi-tui/dist/index.js"),
  typebox: require.resolve("typebox"),
};
const jiti = createJiti(import.meta.url, { alias: aliases });
export const load = (file) => jiti.import(resolve(file));
export const tui = await import(
  pathToFileURL(aliases["@earendil-works/pi-tui"])
);

export async function harness(file, sharedEvents = new EventEmitter()) {
  const hooks = new Map();
  const tools = new Map();
  const commands = new Map();
  const shortcuts = new Map();
  const messageRenderers = new Map();
  const entries = [];
  const messages = [];
  const prompts = [];
  const statuses = new Map();
  const widgets = new Map();
  const notices = [];
  const terminalHandlers = new Set();
  let settings = {};
  const api = {
    on(name, handler) {
      const list = hooks.get(name) ?? [];
      list.push(handler);
      hooks.set(name, list);
    },
    registerTool(tool) {
      tools.set(tool.name, tool);
    },
    registerCommand(name, command) {
      commands.set(name, command);
    },
    registerShortcut(key, shortcut) {
      shortcuts.set(key, shortcut);
    },
    registerMessageRenderer(name, renderer) {
      messageRenderers.set(name, renderer);
    },
    appendEntry(customType, data) {
      entries.push({ type: "custom", customType, data: structuredClone(data) });
    },
    sendMessage(message, options) {
      messages.push({ ...message, options });
    },
    sendUserMessage(content, options) {
      prompts.push({ content, options });
    },
    getSettings() {
      return settings;
    },
    getThinkingLevel() {
      return "high";
    },
    events: {
      on(name, handler) {
        sharedEvents.on(name, handler);
        return () => sharedEvents.off(name, handler);
      },
      emit(name, data) {
        sharedEvents.emit(name, data);
      },
    },
  };
  const ctx = {
    cwd: process.cwd(),
    mode: "tui",
    hasUI: true,
    model: { id: "test", provider: "test" },
    isIdle: () => true,
    hasPendingMessages: () => false,
    abort() {},
    getContextUsage: () => undefined,
    sessionManager: {
      getBranch: () => entries,
      getSessionId: () => "test-session",
      getSessionFile: () => undefined,
    },
    ui: {
      getEditorText: () => "",
      onTerminalInput(handler) {
        terminalHandlers.add(handler);
        return () => terminalHandlers.delete(handler);
      },
      setStatus(key, value) {
        if (value === undefined) statuses.delete(key);
        else statuses.set(key, value);
      },
      setWidget(key, value) {
        if (value === undefined) widgets.delete(key);
        else widgets.set(key, value);
      },
      notify(message, level) {
        notices.push({ message, level });
      },
    },
  };
  const module = await load(file);
  module.default(api);
  return {
    api,
    ctx,
    tools,
    commands,
    shortcuts,
    messageRenderers,
    entries,
    messages,
    prompts,
    statuses,
    widgets,
    notices,
    terminalHandlers,
    setSettings(value) {
      settings = value;
    },
    async emit(name, event = {}) {
      let result;
      for (const handler of hooks.get(name) ?? [])
        result = (await handler({ type: name, ...event }, ctx)) ?? result;
      return result;
    },
  };
}

export const plainTheme = {
  fg: (_color, text) => text,
  bg: (_color, text) => text,
  bold: (text) => text,
};
