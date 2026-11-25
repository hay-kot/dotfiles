---
name: prototype
description: Build a throwaway prototype that answers one design question by running something, instead of debating or asking. Covers a state model or business logic, a UI layout inside the running app, and a behavior, timing, or library probe. Use when the user asks to prototype or try options, or when a planning skill has an open question that a run could settle.
argument-hint: "[question to answer]"
---

# Prototype

A prototype is throwaway code that answers one question. The question decides the shape. No question means no prototype: build the real thing instead.

Prototypes are planning with code. When an open question can be settled by running something (does this state model hold up, which layout reads better, how slow is this call, what does this library do on an empty input), build the smallest thing that shows the answer, observe it, and recommend from what you saw.

## 1. State the question

Write one sentence: the decision this prototype exists to make, and what you will observe to make it. Put it at the top of the prototype too, so the artifact explains itself later.

## 2. Pick a branch

- **Logic** -- "Does this state model or logic hold up?" Read [LOGIC.md](LOGIC.md). One self-contained HTML file with a pure logic module, free-play buttons, and guided scenarios.
- **UI** -- "What should this look like in the app?" Read [UI.md](UI.md). Several structurally different variants on one route of the running app, switched by a `?variant=` param.
- **Probe** -- "What actually happens when...?" A behavior, a timing, a library or API response, a query plan. Write the smallest script that exercises the question and prints what you need to see. No branch file; the rules below cover it.

For visual concepts with no running app to host them, use `/mockups` instead.

If the question is ambiguous and the user is not around, pick the branch that matches the surrounding code (a backend module is Logic or Probe, a page or component is UI) and state the assumption at the top of the prototype.

## Rules for every branch

1. **Throwaway, and marked as such.** Logic and Probe prototypes live in a scratch directory outside the repo (`$TMPDIR/prototype-<slug>/`). UI prototypes live in the app, because they need its data and layout, with `prototype` in every file name. Never commit prototype code.
2. **Trivial to run.** One command or one double-click. Print that command in your reply.
3. **No persistence** unless persistence is the question. Then use a scratch database or file with `prototype` in its name.
4. **Skip the polish.** No tests, no error handling beyond what makes it run, no abstractions.
5. **Show the state.** After every action or variant switch, render or print the full relevant state.
6. **Try more than one option.** When comparing, build two or three structurally different variants behind one switcher, and include one the user did not ask for when it is a real contender.
7. **Observe it yourself.** Run the prototype before you hand it over. Screenshot each UI variant, click through each logic scenario, run each probe and keep its output. Your recommendation cites what you observed, not what you expect.

## 3. Hand back

Reply with:

- The question.
- The variants or probes you built, and the command to run them.
- The evidence: screenshots, printed state, timings, or output.
- Tradeoffs and your recommendation. Leave product and taste calls to the user.
- A plain statement that the prototype is throwaway.

## 4. Capture the answer, then clean up

- Record the verdict and its evidence where the work lives: the Decisions section of the plan or design doc when a planning skill called you, otherwise your reply.
- A Logic demo is worth keeping as a shareable file: save it to `.hive/prototypes/YYYY-MM-DD-<slug>.html` (run `hive drive init` first if `.hive` is missing, never `mkdir`). In a hive session, open it with the hive-drive skill.
- Fold the validated decision into the real code when you build it. Rewrite prototype code to production standard; never promote it as-is.
- Delete UI prototype files and the switcher from the working tree once a variant wins, or when the user is done with them.
