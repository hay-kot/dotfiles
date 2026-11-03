import assert from "node:assert/strict";
import test from "node:test";
import { harness, plainTheme, tui } from "./runtime.mjs";

const question = (header = "Scope", multiSelect = false) => ({
  header,
  question: `Which ${header} should we use?`,
  multiSelect,
  options: [
    {
      label: "A sufficiently long first option label for narrow terminals",
      description:
        "A long description that should wrap under the option label without losing its indentation.",
      preview: "First option preview",
    },
    { label: "Second option", description: "Another choice." },
  ],
});

async function open(questions, signal) {
  const h = await harness(".pi/agent/extensions/ask-user-question.ts");
  let component;
  h.ctx.ui.custom = (factory) =>
    new Promise((resolve) => {
      component = factory({ requestRender() {} }, plainTheme, {}, resolve);
      component.focused = true;
    });
  const promise = h.tools
    .get("ask_user_question")
    .execute("q", { questions }, signal, undefined, h.ctx);
  return { ...h, component, promise };
}

const keys = {
  down: "\x1b[B",
  up: "\x1b[A",
  left: "\x1b[D",
  right: "\x1b[C",
  tab: "\t",
  backtab: "\x1b[Z",
  enter: "\r",
  escape: "\x1b",
};
const press = (component, ...names) =>
  names.forEach((name) => component.handleInput(keys[name] ?? name));

function visible(component, width = 80) {
  const lines = component.render(width);
  for (const line of lines)
    assert.ok(
      tui.visibleWidth(line) <= width,
      `${tui.visibleWidth(line)} > ${width}: ${line}`,
    );
  return lines;
}

test("compact step bar tracks answers and selections survive navigation", async () => {
  const { component, promise } = await open([question(), question("Style")]);
  const initial = visible(component).join("\n");
  assert.match(initial, /\[> 1 Scope\].*\[2 Style\].*\[Review\]/);
  assert.match(initial, /Which Scope should we use\?/);
  assert.doesNotMatch(initial, /Which Style should we use\?/);
  press(component, "enter");
  assert.match(visible(component).join("\n"), /\[x 1 Scope\]/);
  press(component, "backtab");
  press(component, "down", "enter");
  press(component, "enter");
  assert.match(visible(component).join("\n"), /Enter to submit answers/);
  press(component, "enter");
  const response = await promise;
  assert.equal(response.details.answers[0].answer, "Second option");
  assert.equal(response.details.answers[1].preview, "First option preview");
});

test("custom input has cursor, supports paste, unicode and cursor editing", async () => {
  const { component, promise } = await open([question()]);
  press(component, "down", "down");
  assert.ok(
    visible(component).some((line) => line.includes(tui.CURSOR_MARKER)),
  );
  component.handleInput("\x1b[200~café 測試\x1b[201~");
  press(component, "left", "!");
  visible(component, 20);
  press(component, "enter");
  const response = await promise;
  assert.equal(response.details.answers[0].answer, "café 測!試");
});

test("option labels use hanging indentation and render correctly after resize", async () => {
  const { component, promise } = await open([question()]);
  const narrow = visible(component, 27);
  const index = narrow.findIndex((line) => line.startsWith("> 1. "));
  assert.ok(index >= 0);
  assert.match(narrow[index + 1], /^ {5}\S/);
  assert.ok(visible(component, 100).length < narrow.length);
  for (const width of [1, 4, 8, 16, 40]) visible(component, width);
  press(component, "escape");
  assert.equal((await promise).details.cancelled, true);
});

test("multi-select combines options, previews and custom text", async () => {
  const { component, promise } = await open([question("Scope", true)]);
  press(component, " ", "down", "enter", "down");
  component.handleInput("\x1b[200~Also this\x1b[201~");
  assert.ok(
    visible(component).some((line) => line.includes(tui.CURSOR_MARKER)),
  );
  press(component, "enter");
  const answer = (await promise).details.answers[0];
  assert.equal(answer.kind, "multi");
  assert.equal(answer.selected.length, 3);
  assert.equal(answer.selected[2], "Also this");
  assert.equal(answer.preview, "First option preview");
});

test("editing an answered question requires confirmation again", async () => {
  const { component, promise } = await open([question(), question("Style")]);
  press(component, "enter", "backtab", "down", "down", "x", "tab", "tab");
  assert.match(visible(component).join("\n"), /Answer each question/);
  press(component, "escape");
  await promise;
});

test("abort closes the questionnaire, and chat returns partial answers", async () => {
  const controller = new AbortController();
  const aborted = await open([question()], controller.signal);
  controller.abort();
  assert.equal((await aborted.promise).details.cancelled, true);
  const chat = await open([question(), question("Style")]);
  press(chat.component, "enter", "down", "down", "down", "down", "enter");
  const response = await chat.promise;
  assert.equal(response.details.answers[1].kind, "chat");
  assert.match(response.content[0].text, /wants to chat/);
});

test("input and preview rows stay stable across focus changes and long answers", async () => {
  for (const multi of [false, true]) {
    const q = question("Scope", multi);
    q.options[1].preview =
      "A longer preview that wraps across several lines at narrower terminal widths, without moving the controls below it.";
    const { component, promise } = await open([q]);
    for (const width of [27, 80]) {
      const initial = visible(component, width);
      const submitRow = initial.findIndex((line) => line.trim() === "Submit");
      for (let i = 0; i < q.options.length + 2; i++) {
        press(component, "down");
        const lines = visible(component, width);
        assert.equal(lines.length, initial.length);
        assert.equal(
          lines.findIndex(
            (line) => line.replace(/^> /, "  ").trim() === "Submit",
          ),
          submitRow,
        );
      }
      press(component, "up", "up", "up", "up", "down", "down");
      component.handleInput(
        "\x1b[200~A long custom answer " +
          "with extra text ".repeat(20) +
          "\x1b[201~",
      );
      assert.equal(visible(component, width).length, initial.length);
      press(component, "up", "up");
      assert.equal(visible(component, width).length, initial.length);
    }
    press(component, "escape");
    await promise;
  }
});

test("single-choice questions have no inert Submit button", async () => {
  const { component, promise } = await open([question()]);
  assert.doesNotMatch(visible(component).join("\n"), /Submit/);
  press(component, "down", "down");
  component.handleInput("\x1b[200~Custom choice\x1b[201~");
  press(component, "enter");
  assert.equal((await promise).details.answers[0].answer, "Custom choice");
});

test("multi-select Submit appears only when usable and sends selected answers", async () => {
  const { component, promise } = await open([question("Scope", true)]);
  const initialHeight = visible(component).length;
  assert.doesNotMatch(visible(component).join("\n"), /Submit/);
  press(component, "down", "down", "down");
  assert.match(visible(component).join("\n"), /> Chat about this/);
  press(component, "up", "up", "up", " ");
  assert.equal(visible(component).length, initialHeight);
  assert.match(visible(component).join("\n"), /Submit/);
  press(component, "down", "down", "down");
  assert.match(visible(component).join("\n"), /> Submit/);
  press(component, "enter");
  assert.equal((await promise).details.answers[0].selected.length, 1);
});

test("custom text replaces its label inline for single and multi-select", async () => {
  for (const multi of [false, true]) {
    const { component, promise } = await open([question("Scope", multi)]);
    const initial = visible(component);
    const row = initial.findIndex((line) => line.includes("Type something."));
    assert.ok(row >= 0);
    press(component, "down", "down");
    const focused = visible(component);
    assert.equal(focused.length, initial.length);
    assert.ok(focused[row].includes(tui.CURSOR_MARKER));
    assert.match(focused[row], multi ? /^> 3\. \[ \] / : /^> 3\. /);
    assert.doesNotMatch(
      focused.join("\n"),
      /Type something\.|Type your answer/,
    );
    component.handleInput("\x1b[200~Inline answer\x1b[201~");
    assert.match(visible(component)[row], /Inline answer/);
    press(component, "up");
    assert.match(visible(component)[row], /Inline answer/);
    assert.equal(visible(component).length, initial.length);
    press(component, "escape");
    await promise;
  }
});

test("RPC and print modes return an explicit unsupported-UI result", async () => {
  const h = await harness(".pi/agent/extensions/ask-user-question.ts");
  for (const mode of ["rpc", "print", "json"]) {
    h.ctx.mode = mode;
    const response = await h.tools
      .get("ask_user_question")
      .execute("q", { questions: [question()] }, undefined, undefined, h.ctx);
    assert.equal(response.details.error, "no_ui");
  }
});
