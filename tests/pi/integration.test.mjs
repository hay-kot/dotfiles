import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { join } from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import test from "node:test";
import { pathToFileURL } from "node:url";
import { stripVTControlCharacters } from "node:util";
import { harness, plainTheme, piDirectory, tui } from "./runtime.mjs";

function shellResult(h, toolCallId, overrides = {}) {
  return h.tools
    .get("bash")
    .renderResult(
      overrides.result ?? { content: [] },
      { expanded: false, isPartial: overrides.isPartial ?? true },
      overrides.theme ?? plainTheme,
      {
        toolCallId,
        args: {},
        state: {},
        executionStarted: true,
        showImages: false,
        cwd: process.cwd(),
        invalidate() {},
        ...overrides.context,
      },
    );
}

function hasShellHint(h, toolCallId) {
  return shellResult(h, toolCallId)
    .render(80)
    .some((line) => line.includes("Ctrl+B Ctrl+B"));
}

const files = [
  ".pi/agent/extensions/ask-user-question.ts",
  ".pi/agent/extensions/custom-footer.ts",
  ".pi/agent/extensions/background-shell/index.ts",
  ".pi/agent/extensions/goal/index.ts",
];

test("Pi's actual extension loader accepts all four extensions", async () => {
  const { loadExtensions } = await import(
    pathToFileURL(join(piDirectory, "dist/core/extensions/loader.js"))
  );
  const result = await loadExtensions(files, process.cwd());
  assert.deepEqual(result.errors, []);
  assert.equal(result.extensions.length, 4);
});

test("Pi queues background follow-ups behind in-flight tool results", async () => {
  const { AgentSession } = await import(
    pathToFileURL(join(piDirectory, "dist/core/agent-session.js"))
  );
  const queued = [];
  const fakeSession = {
    isStreaming: true,
    agent: {
      followUp(message) {
        queued.push(message);
      },
      steer() {
        assert.fail("Must not steer");
      },
    },
    _appendCustomMessage() {
      assert.fail("Must not append between a tool call and its result");
    },
    _startRun() {
      assert.fail("Must not start a concurrent request");
    },
  };
  await AgentSession.prototype.sendCustomMessage.call(
    fakeSession,
    {
      customType: "shell-complete",
      content: "Command finished",
      display: true,
    },
    { triggerTurn: true, deliverAs: "followUp" },
  );
  assert.equal(queued.length, 1);
  assert.equal(queued[0].customType, "shell-complete");
});

test("footer renders shell and goal statuses within narrow terminal widths", async () => {
  const h = await harness(".pi/agent/extensions/custom-footer.ts");
  let footer;
  h.ctx.ui.theme = plainTheme;
  h.ctx.ui.setFooter = (factory) => {
    footer = factory({ requestRender() {} }, plainTheme, {
      onBranchChange: () => () => {},
      getGitBranch: () => "feat/pi-bg-bash",
      getExtensionStatuses: () =>
        new Map([
          ["shells", "shells (2)"],
          ["goal", "/goal active | 3/20 turns\nprogress"],
          ["hive-active-task", "hc-demo active task"],
          ["hive-inbox", "Hive inbox"],
        ]),
    });
  };
  await h.emit("session_start");
  const rendered = footer.render(80);
  const output = rendered.join("\n");
  assert.equal(rendered.length, 2);
  assert.match(rendered[0], /feat\/pi-bg-bash.*shells \(2\)/);
  assert.equal(output.match(/shells \(2\)/g).length, 1);
  assert.match(footer.render(20)[0], /shells \(2\)/);
  assert.match(output, /\/goal active/);
  assert.match(output, /turns progress/);
  assert.doesNotMatch(output, /hc-demo|Hive inbox/);
  for (const width of [1, 5, 20, 80]) {
    for (const line of footer.render(width))
      assert.ok(tui.visibleWidth(line) <= width);
  }
  footer.dispose();
});

test("shell footer uses accent color and highlights keyboard selection", async () => {
  const bus = new EventEmitter();
  const h = await harness(files[1], bus);
  const styles = [];
  let footer;
  h.ctx.ui.theme = {
    ...plainTheme,
    fg(color, text) {
      styles.push(["fg", color, text]);
      return text;
    },
    bg(color, text) {
      styles.push(["bg", color, text]);
      return text;
    },
  };
  h.ctx.ui.setFooter = (factory) => {
    footer = factory({ requestRender() {} }, h.ctx.ui.theme, {
      onBranchChange: () => () => {},
      getGitBranch: () => "feature",
      getExtensionStatuses: () => new Map([["shells", "shells (1)"]]),
    });
  };
  await h.emit("session_start");
  footer.render(80);
  assert.ok(
    styles.some(
      ([kind, color, text]) =>
        kind === "fg" && color === "accent" && text === "shells (1)",
    ),
  );
  bus.emit("dotfiles:shell-footer", { focused: true });
  footer.render(80);
  assert.ok(
    styles.some(([kind, color]) => kind === "bg" && color === "selectedBg"),
  );
  footer.dispose();
  assert.equal(bus.listenerCount("dotfiles:shell-footer"), 0);
});

test("Down and Enter open background-shell previews without stealing editor or dialog keys", async (t) => {
  const bus = new EventEmitter();
  const h = await harness(files[2], bus);
  let component;
  t.after(async () => {
    component?.dispose();
    await h.emit("session_shutdown");
  });
  await h.emit("session_start");
  let draft = "";
  h.ctx.ui.getEditorText = () => draft;
  let focused = false;
  bus.on("dotfiles:shell-footer", (data) => {
    focused = data.focused;
  });
  const input = [...h.terminalHandlers][0];
  const down = "\x1b[B";
  const up = "\x1b[A";
  assert.equal(input(down), undefined);
  const bash = h.tools.get("bash");
  const first = await bash.execute(
    "first",
    { command: "printf first-preview; sleep 30", background: true },
    undefined,
    undefined,
    h.ctx,
  );
  await bash.execute(
    "second",
    { command: "printf second-preview; sleep 30", background: true },
    undefined,
    undefined,
    h.ctx,
  );
  await delay(30);
  draft = "unfinished\nprompt";
  assert.equal(input(down), undefined);
  assert.equal(focused, false);
  draft = "";
  await h.emit("ui_prompt_start");
  assert.equal(input(down), undefined);
  await h.emit("ui_prompt_end");
  assert.deepEqual(input(down), { consume: true });
  assert.equal(focused, true);
  assert.deepEqual(input(up), { consume: true });
  assert.equal(focused, false);
  input(down);
  assert.equal(input("x"), undefined);
  assert.equal(focused, false);
  input(down);
  assert.deepEqual(input("\x1b"), { consume: true });
  assert.equal(focused, false);
  h.ctx.ui.custom = (factory) =>
    new Promise((resolve) => {
      component = factory({ requestRender() {} }, plainTheme, {}, resolve);
    });
  input(down);
  assert.deepEqual(input("\r"), { consume: true });
  assert.ok(component);
  assert.equal(focused, false);
  const preview = () => {
    return component.render(80).join("\n");
  };
  assert.match(preview(), /second-preview/);
  assert.equal(input(down), undefined);
  component.handleInput(down);
  assert.match(preview(), /first-preview/);
  await bash.execute(
    "third",
    { command: "sleep 30", background: true },
    undefined,
    undefined,
    h.ctx,
  );
  assert.match(preview(), /first-preview/);
  assert.ok(
    component
      .render(80)
      .some((line) => line.includes(`> ${first.structuredContent.job_id} `)),
  );
  component.handleInput("\x1b");
  await delay(0);
  assert.deepEqual(input(down), { consume: true });
  assert.equal(focused, true);
});

test("finishing the last background shell releases footer selection", async (t) => {
  const bus = new EventEmitter();
  const h = await harness(files[2], bus);
  t.after(() => h.emit("session_shutdown"));
  await h.emit("session_start");
  let focused = false;
  bus.on("dotfiles:shell-footer", (data) => {
    focused = data.focused;
  });
  await h.tools
    .get("bash")
    .execute(
      "short",
      { command: "sleep 0.1", background: true },
      undefined,
      undefined,
      h.ctx,
    );
  const input = [...h.terminalHandlers][0];
  input("\x1b[B");
  assert.equal(focused, true);
  await delay(200);
  assert.equal(focused, false);
  assert.equal(h.statuses.has("shells"), false);
  assert.equal(input("\r"), undefined);
});

test("reload removes shell/goal event listeners and leaves editor Ctrl+B untouched while idle", async () => {
  const bus = new EventEmitter();
  const shells = await harness(files[2], bus);
  const goal = await harness(files[3], bus);
  await shells.emit("session_start");
  await goal.emit("session_start");
  assert.equal(bus.listenerCount("dotfiles:shell-query"), 1);
  assert.equal(bus.listenerCount("dotfiles:shell-jobs"), 1);
  const handler = [...shells.terminalHandlers][0];
  assert.equal(handler("\x02"), undefined);
  const pending = shells.tools
    .get("bash")
    .execute("fg", { command: "sleep 30" }, undefined, undefined, shells.ctx);
  assert.equal(shells.statuses.has("shells"), false);
  assert.equal(hasShellHint(shells, "fg"), true);
  assert.equal(handler("\x02"), undefined);
  assert.deepEqual(handler("\x02"), { consume: true });
  const running = await pending;
  assert.equal(hasShellHint(shells, "fg"), false);
  assert.equal(running.structuredContent.status, "running");
  await shells.emit("session_shutdown");
  await goal.emit("session_shutdown");
  assert.equal(bus.listenerCount("dotfiles:shell-query"), 0);
  assert.equal(bus.listenerCount("dotfiles:shell-jobs"), 0);
  assert.equal(shells.terminalHandlers.size, 0);
  assert.equal(shells.widgets.size, 0);
  assert.equal(shells.messages.length, 0);
});

test("double Ctrl+B requires consecutive timely presses for the same foreground shell", async (t) => {
  const h = await harness(files[2]);
  t.after(() => h.emit("session_shutdown"));
  await h.emit("session_start");
  let now = Date.now();
  t.mock.method(Date, "now", () => now);
  const input = [...h.terminalHandlers][0];
  const bash = h.tools.get("bash");
  const pending = bash.execute(
    "first",
    { command: "sleep 30", yield_ms: 600000 },
    undefined,
    undefined,
    h.ctx,
  );
  assert.equal(input("\x02"), undefined);
  now += 751;
  assert.equal(input("\x02"), undefined);
  assert.equal(input("x"), undefined);
  assert.equal(input("\x02"), undefined);
  await h.emit("ui_prompt_start");
  assert.equal(hasShellHint(h, "first"), false);
  assert.equal(input("\x02"), undefined);
  await h.emit("ui_prompt_end");
  assert.equal(hasShellHint(h, "first"), true);
  assert.equal(input("\x02"), undefined);

  const second = bash.execute(
    "second",
    { command: "sleep 30", yield_ms: 600000 },
    undefined,
    undefined,
    h.ctx,
  );
  assert.equal(input("\x02"), undefined);
  now += 750;
  assert.deepEqual(input("\x02"), { consume: true });
  const result = await second;
  assert.equal(result.structuredContent.job_id, "shell-2");
  assert.equal(hasShellHint(h, "first"), true);
  assert.equal(hasShellHint(h, "second"), false);
  assert.equal(input("\x02"), undefined);
  assert.deepEqual(input("\x02"), { consume: true });
  assert.equal((await pending).structuredContent.job_id, "shell-1");
  assert.equal(hasShellHint(h, "first"), false);
  assert.equal(input("\x02"), undefined);
});

test("foreground hint clears on completion, automatic yield, abort, and shutdown", async (t) => {
  const h = await harness(files[2]);
  t.after(() => h.emit("session_shutdown"));
  await h.emit("session_start");
  const bash = h.tools.get("bash");
  for (const params of [
    { command: "true" },
    { command: "sleep 30", yield_ms: 10 },
    { command: "sleep 30", background: true },
  ]) {
    const pending = bash.execute("hint", params, undefined, undefined, h.ctx);
    assert.equal(hasShellHint(h, "hint"), true);
    await pending;
    assert.equal(hasShellHint(h, "hint"), false);
  }
  const controller = new AbortController();
  const aborted = bash.execute(
    "abort",
    { command: "sleep 30" },
    controller.signal,
    undefined,
    h.ctx,
  );
  assert.equal(hasShellHint(h, "abort"), true);
  controller.abort();
  await assert.rejects(aborted, /abort/i);
  assert.equal(hasShellHint(h, "abort"), false);

  const shutdown = bash.execute(
    "shutdown",
    { command: "sleep 30" },
    undefined,
    undefined,
    h.ctx,
  );
  assert.equal(hasShellHint(h, "shutdown"), true);
  await h.emit("session_shutdown");
  await shutdown;
  assert.equal(hasShellHint(h, "shutdown"), false);
});

test("shell hint uses dim text directly below output without a widget or blank line", async (t) => {
  const { initTheme } = await import(
    pathToFileURL(join(piDirectory, "dist/modes/interactive/theme/theme.js"))
  );
  initTheme("dark", false);
  const h = await harness(files[2]);
  t.after(() => h.emit("session_shutdown"));
  await h.emit("session_start");
  const pending = h.tools
    .get("bash")
    .execute(
      "styled",
      { command: "sleep 30", yield_ms: 600000 },
      undefined,
      undefined,
      h.ctx,
    );
  const styles = [];
  const theme = {
    ...plainTheme,
    fg(color, text) {
      styles.push([color, text]);
      return text;
    },
  };
  const result = { content: [{ type: "text", text: "Shell output" }] };
  let component = shellResult(h, "styled", { result, theme });
  assert.deepEqual(
    component
      .render(80)
      .map((line) => stripVTControlCharacters(line).trimEnd())
      .slice(-2),
    ["Shell output", "Ctrl+B Ctrl+B to background"],
  );
  assert.deepEqual(styles.at(-1), ["dim", "Ctrl+B Ctrl+B to background"]);
  assert.equal(h.widgets.size, 0);
  assert.equal(hasShellHint(h, "unrelated-tool"), false);
  for (const width of [1, 12, 80]) {
    for (const line of component.render(width))
      assert.ok(tui.visibleWidth(line) <= width);
  }
  component = shellResult(h, "styled", {
    result,
    theme,
    context: { lastComponent: component },
  });
  assert.equal(
    component.render(80).filter((line) => line.includes("Ctrl+B")).length,
    1,
  );
  const input = [...h.terminalHandlers][0];
  input("\x02");
  input("\x02");
  const finished = await pending;
  assert.doesNotMatch(component.render(80).join("\n"), /Ctrl\+B/);
  const final = shellResult(h, "styled", {
    result: finished,
    isPartial: false,
    context: { lastComponent: component },
  });
  assert.doesNotMatch(final.render(80).join("\n"), /Ctrl\+B/);
});

test("non-TUI shell execution does not install terminal hints or input handlers", async (t) => {
  const h = await harness(files[2]);
  t.after(() => h.emit("session_shutdown"));
  h.ctx.mode = "rpc";
  h.ctx.ui.setWidget = () => assert.fail("No terminal widget outside TUI mode");
  await h.emit("session_start");
  await h.tools
    .get("bash")
    .execute("rpc", { command: "true" }, undefined, undefined, h.ctx);
  assert.equal(h.terminalHandlers.size, 0);
});
