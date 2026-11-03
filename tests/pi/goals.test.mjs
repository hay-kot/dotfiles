import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import test from "node:test";
import { harness, load } from "./runtime.mjs";

const state = await load(".pi/agent/extensions/goal/state.ts");
const lastGoal = (h) => h.entries.at(-1)?.data;
const boundary = (overrides = {}) => ({
  outcome: "completed",
  continue: false,
  entries: [],
  context: {
    canContinue: true,
    contextMessages: [
      {
        role: "toolResult",
        toolName: "bash",
        isError: false,
        content: [{ type: "text", text: "All tests pass" }],
      },
    ],
  },
  ...overrides,
});

async function setup(t, input = "Tests pass", bus) {
  const h = await harness(".pi/agent/extensions/goal/index.ts", bus);
  t.after(() => h.emit("session_shutdown"));
  const requests = [];
  let verdict = { verdict: "not_met", reason: "Run the build too" };
  h.ctx.modelRegistry = {
    find(provider, id) {
      return provider === "test" && id === "small"
        ? { provider, id }
        : undefined;
    },
    hasConfiguredAuth: () => true,
    streamSimple(model, request, options) {
      requests.push({ model, request, options });
      return {
        async result() {
          return {
            usage: { output: 15 },
            stopReason: "stop",
            content: [
              {
                type: "text",
                text:
                  typeof verdict === "string"
                    ? verdict
                    : JSON.stringify(verdict),
              },
            ],
          };
        },
      };
    },
  };
  await h.emit("session_start");
  await h.commands.get("goal").handler(input, h.ctx);
  return {
    ...h,
    requests,
    verdict(value) {
      verdict = value;
    },
  };
}

test("goal parsing applies limits and validates input and verdicts", () => {
  const goal = state.newGoal("--max-turns 4 --max-tokens 500 Run all tests");
  assert.equal(goal.maxTurns, 4);
  assert.equal(goal.maxTokens, 500);
  assert.equal(goal.condition, "Run all tests");
  assert.throws(() => state.newGoal("--max-turns 0 x"), /positive/);
  assert.throws(() => state.newGoal("--max-turns x objective"), /Usage/);
  assert.throws(() => state.newGoal("x".repeat(4001)), /4000/);
  assert.equal(state.restoreGoal(goal).id, goal.id);
  assert.equal(state.restoreGoal({ id: "bad" }), undefined);
  assert.equal(
    state.parseVerdict('```json\n{"verdict":"met","reason":"Tests pass"}\n```')
      .verdict,
    "met",
  );
  assert.throws(
    () => state.parseVerdict('{"verdict":"maybe","reason":""}'),
    /invalid/,
  );
});

test("goal starts work immediately and independently evaluates before continuation", async (t) => {
  const h = await setup(t);
  assert.equal(h.prompts.length, 1);
  assert.match(
    (await h.emit("before_agent_start")).message.content,
    /Active goal: Tests pass/,
  );
  await h.emit("tool_execution_end");
  const result = await h.emit("agent_before_settle", boundary());
  assert.equal(result.continue, true);
  assert.match(result.entries[0].content, /Run the build too/);
  assert.equal(h.requests.length, 1);
  assert.equal(h.requests[0].request.tools, undefined);
  assert.match(h.requests[0].request.messages[0].content, /All tests pass/);
  assert.equal(lastGoal(h).turns, 1);
  assert.equal(lastGoal(h).outputTokens, 15);
  h.verdict({ verdict: "met", reason: "Build and tests succeeded" });
  assert.equal(await h.emit("agent_before_settle", boundary()), undefined);
  assert.equal(lastGoal(h).status, "met");
  assert.equal(h.statuses.has("goal"), false);
});

test("impossible verdict ends work; malformed evaluator output pauses safely", async (t) => {
  const h = await setup(t);
  h.verdict("not json");
  await h.emit("agent_before_settle", boundary());
  assert.equal(lastGoal(h).status, "paused");
  await h.commands.get("goal").handler("resume", h.ctx);
  h.verdict({
    verdict: "impossible",
    reason: "Required service credentials are unavailable",
  });
  await h.emit("agent_before_settle", boundary());
  assert.equal(lastGoal(h).status, "impossible");
});

test("interrupts, errors and cancelled questions do not restart work", async (t) => {
  for (const outcome of ["aborted", "error"]) {
    const h = await setup(t);
    await h.emit("agent_before_settle", boundary({ outcome }));
    assert.equal(lastGoal(h).status, "paused");
    assert.equal(h.requests.length, 0);
  }
  const h = await setup(t);
  await h.emit("tool_result", {
    toolName: "ask_user_question",
    details: { answers: [{ kind: "chat" }] },
  });
  assert.equal(lastGoal(h).status, "paused");
  assert.equal(await h.emit("agent_before_settle", boundary()), undefined);
});

test("turn and token budgets stop loops and count worker plus evaluator output", async (t) => {
  const h = await setup(t, "--max-turns 1 Tests pass");
  await h.emit("tool_execution_end");
  await h.emit("message_end", {
    message: { role: "assistant", usage: { output: 200 } },
  });
  await h.emit("agent_before_settle", boundary());
  assert.equal(lastGoal(h).status, "paused");
  assert.equal(lastGoal(h).outputTokens, 215);
  assert.match(lastGoal(h).reason, /1 evaluated turns/);
  await h.commands.get("goal").handler("resume", h.ctx);
  assert.equal(lastGoal(h).status, "paused");
  const tokens = await setup(t, "--max-tokens 5 Tests pass");
  await tokens.emit("message_end", {
    message: { role: "assistant", usage: { output: 10 } },
  });
  await tokens.emit("agent_before_settle", boundary());
  assert.equal(lastGoal(tokens).status, "paused");
  assert.equal(tokens.requests.length, 0);
});

test("output budget interrupts an ongoing tool loop at its next turn boundary", async (t) => {
  const h = await setup(t, "--max-tokens 5 Tests pass");
  let interrupted = false;
  h.ctx.abort = () => {
    interrupted = true;
  };
  await h.emit("message_end", {
    message: { role: "assistant", usage: { output: 10 } },
  });
  await h.emit("turn_end");
  assert.equal(lastGoal(h).status, "paused");
  assert.equal(interrupted, true);
  assert.equal(h.requests.length, 0);
});

test("three rounds without tools pause; pending work defers evaluation", async (t) => {
  const h = await setup(t);
  for (let i = 0; i < 3; i++) await h.emit("agent_before_settle", boundary());
  assert.equal(lastGoal(h).status, "paused");
  assert.match(lastGoal(h).reason, /No tool use/);
  const pending = await setup(t);
  await pending.emit("agent_before_settle", boundary({ continue: true }));
  pending.ctx.hasPendingMessages = () => true;
  await pending.emit("agent_before_settle", boundary());
  assert.equal(pending.requests.length, 0);
});

test("background shells defer evaluation until their completion", async (t) => {
  const bus = new EventEmitter();
  const h = await setup(t, "Tests pass", bus);
  bus.emit("dotfiles:shell-jobs", { running: 1 });
  assert.equal(await h.emit("agent_before_settle", boundary()), undefined);
  assert.equal(h.requests.length, 0);
  assert.match(lastGoal(h).reason, /Waiting for 1/);
  bus.emit("dotfiles:shell-jobs", { running: 0 });
  await h.emit("agent_before_settle", boundary());
  assert.equal(h.requests.length, 1);
});

test("goal state survives resume and compaction, respects branch state and clear", async (t) => {
  const h = await setup(t);
  await h.emit("message_end", {
    message: { role: "assistant", usage: { output: 20 } },
  });
  await h.emit("session_start");
  assert.equal(lastGoal(h).status, "active");
  assert.equal(h.prompts.length, 1);
  assert.match(
    (await h.emit("before_agent_start")).message.content,
    /Tests pass/,
  );
  await h.emit("session_tree");
  assert.equal(lastGoal(h).status, "paused");
  await h.commands.get("goal").handler("clear", h.ctx);
  await h.emit("session_start");
  assert.equal(lastGoal(h).status, "cleared");
  assert.equal(await h.emit("agent_before_settle", boundary()), undefined);
  h.ctx.sessionManager.getBranch = () => [];
  await h.emit("session_start");
  assert.equal(h.statuses.has("goal"), false);
});

test("an explicit available evaluator model persists without changing the worker model", async (t) => {
  const h = await setup(t);
  await h.commands.get("goal").handler("model test/small", h.ctx);
  await h.emit("session_start");
  await h.emit("agent_before_settle", boundary());
  assert.equal(h.requests[0].model.id, "small");
  assert.equal(h.ctx.model.id, "test");
  assert.equal(lastGoal(h).evaluatorModel, "test/small");
  await h.commands.get("goal").handler("model missing/model", h.ctx);
  assert.equal(h.notices.at(-1).level, "error");
  assert.equal(lastGoal(h).evaluatorModel, "test/small");
  await h.commands.get("goal").handler("model current", h.ctx);
  assert.equal(lastGoal(h).evaluatorModel, undefined);
});

test("native subagents defer goal evaluation and their completion releases it", async (t) => {
  const bus = new EventEmitter();
  const h = await setup(t, "Tests pass", bus);
  bus.emit("subagent:async-started", {
    id: "other",
    sessionId: "another-session",
  });
  bus.emit("subagent:async-started", {
    id: "child",
    sessionId: "test-session",
  });
  assert.equal(await h.emit("agent_before_settle", boundary()), undefined);
  assert.equal(h.requests.length, 0);
  bus.emit("subagent:async-complete", { runId: "child" });
  await h.emit("agent_before_settle", boundary());
  assert.equal(h.requests.length, 1);
  await h.commands.get("goal").handler("pause", h.ctx);
  assert.match(
    (await h.emit("before_agent_start")).message.content,
    /loop is paused/,
  );
  await h.emit("session_shutdown");
  assert.equal(bus.listenerCount("subagent:async-started"), 0);
  assert.equal(bus.listenerCount("subagent:async-complete"), 0);
});

test("clearing or replacing a goal during evaluation invalidates a stale verdict", async (t) => {
  const h = await setup(t);
  let resolve;
  h.ctx.modelRegistry.streamSimple = () => ({
    result: () =>
      new Promise((done) => {
        resolve = done;
      }),
  });
  const evaluation = h.emit("agent_before_settle", boundary());
  await h.commands.get("goal").handler("clear", h.ctx);
  resolve({
    usage: { output: 5 },
    content: [
      { type: "text", text: '{"verdict":"not_met","reason":"Continue"}' },
    ],
  });
  assert.equal(await evaluation, undefined);
  assert.equal(lastGoal(h).status, "cleared");
});
