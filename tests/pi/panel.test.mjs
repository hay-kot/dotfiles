import assert from "node:assert/strict";
import { stripVTControlCharacters } from "node:util";
import test from "node:test";
import { load, plainTheme, tui } from "./runtime.mjs";

const { renderShellPanel } = await load(
  ".pi/agent/extensions/background-shell/panel.ts",
);
const jobs = Array.from({ length: 3 }, (_, i) => ({
  id: `shell-${i + 1}`,
  command: `run-task-${i + 1} ${"argument ".repeat(40)}`,
  status: "running",
  startedAt: Date.now() - 11000,
}));
const plain = (lines) => lines.map(stripVTControlCharacters).join("\n");

test("wide shell panel separates short shell rows from the selected command and output", () => {
  const lines = renderShellPanel(
    112,
    jobs,
    1,
    "Selected shell output",
    plainTheme,
  );
  const text = plain(lines);
  assert.match(text, /╭─+╮/);
  assert.match(text, /Shell\s+State\s+Age/);
  assert.match(text, /> shell-2/);
  assert.match(text, /Output\s+shell-2/);
  assert.match(text, /Selected shell output/);
  assert.equal(text.match(/Command:/g).length, 1);
  assert.match(text, /run-task-2/);
  assert.doesNotMatch(text, /run-task-1|run-task-3/);
  for (const line of lines) assert.equal(tui.visibleWidth(line), 112);
});

test("shell panel stacks on small terminals and fills the available width", () => {
  for (const width of [1, 5, 12, 20, 40, 75, 76, 80, 112, 240]) {
    const lines = renderShellPanel(
      width,
      jobs,
      0,
      "Wide text 測試\n".repeat(30),
      plainTheme,
    );
    for (const line of lines) {
      if (width >= 12) assert.equal(tui.visibleWidth(line), width);
      else assert.ok(tui.visibleWidth(line) <= width);
    }
    if (width >= 12) assert.ok(lines.length <= 22);
  }
  const narrow = renderShellPanel(40, jobs, 0, "Output", plainTheme);
  assert.equal(
    narrow.filter((line) => stripVTControlCharacters(line).startsWith("├"))
      .length,
    3,
  );
  const wide = renderShellPanel(112, jobs, 0, "Output", plainTheme);
  assert.equal(
    wide.filter((line) => stripVTControlCharacters(line).startsWith("├"))
      .length,
    2,
  );
});

test("output preview keeps a fixed height and shows the latest lines", () => {
  for (const width of [40, 112]) {
    const empty = renderShellPanel(width, jobs, 0, "", plainTheme);
    const full = renderShellPanel(
      width,
      jobs,
      0,
      Array.from({ length: 50 }, (_, i) => `log-line-${i}`).join("\n"),
      plainTheme,
    );
    assert.equal(full.length, empty.length);
    assert.match(plain(empty), /Waiting for output/);
    assert.match(plain(full), /log-line-49/);
    assert.doesNotMatch(plain(full), /log-line-0\s/);
  }
});

test("selection highlights the whole shell row and stays in the list viewport", () => {
  const highlighted = [];
  const theme = {
    ...plainTheme,
    bg(color, text) {
      highlighted.push({ color, text });
      return text;
    },
  };
  const many = Array.from({ length: 20 }, (_, i) => ({
    ...jobs[0],
    id: `shell-${i + 1}`,
  }));
  const text = plain(renderShellPanel(112, many, 19, "tail", theme));
  assert.equal(highlighted.length, 1);
  assert.equal(highlighted[0].color, "selectedBg");
  assert.match(highlighted[0].text, /> shell-20/);
  assert.match(text, /> shell-20/);
  assert.doesNotMatch(text, /shell-1\s/);
});

test("empty panels and terminal controls do not corrupt the panel", () => {
  const empty = plain(renderShellPanel(112, [], 0, "", plainTheme));
  assert.match(empty, /No background shells/);
  assert.match(empty, /Select a shell/);
  const text = plain(
    renderShellPanel(
      80,
      jobs,
      0,
      "\x1b[2Jbad\btext\toutput\r\nnext",
      plainTheme,
    ),
  );
  assert.doesNotMatch(text, /[\x00-\x09\x0b-\x1f\x7f]/);
  assert.match(text, /badtext  output/);
});
