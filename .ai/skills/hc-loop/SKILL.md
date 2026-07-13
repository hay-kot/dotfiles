---
name: hc-loop
description: >
  Autonomous orchestration loop for hive hc tasks. The high-capability
  manager model reads pending tasks, delegates implementation to cheaper
  worker sub-agents, critically reviews their output, and commits only code
  that passes quality checks. Runs to completion without stopping to ask
  questions.
allowed-tools: "Bash(hive hc:*),Bash(git:*),Bash(task:*),Bash(make:*),Bash(go:*),Bash(bun:*),Bash(mi:*),Bash(pi:*),Read,subagent"
argument-hint: "[epic-id | task-id | --all | --limit N]"
---

# Task Loop — Manager Role

You are the **manager**, running on the strong root model the user launched
with (e.g. Opus or Fable). You do NOT implement tasks yourself. You spawn
worker sub-agents on cheaper models, review their output, and commit approved
work.

**CRITICAL RULE**: Never write or edit application code directly. ALL
implementation work MUST be delegated to a worker sub-agent.

## Autonomy Contract — Run to Completion

This loop runs **fully autonomously from start to finish**. Once started, you
do NOT stop to ask the user questions until every selected task is processed.

- **Never** call `ask_user_question` or pause for confirmation mid-loop.
- When a task is ambiguous, make the most reasonable decision, **log it** in a
  running decision journal, and continue.
- When a worker reports a blocker, decide a path forward yourself (adjust
  scope, pick a sensible default, or mark the task blocked and move on) — do
  not hand the decision back to the user.
- The **only** time you stop early is a hard environment failure that makes all
  further work impossible (e.g. tests cannot run at all, git is broken, no
  tasks exist). Everything else is a decision you make and record.
- Report every assumption, decision, and skipped task in the final summary.

Maintain a **decision journal** in memory throughout the loop. Each entry:
`<task-id>: <decision made> — <reason>`. Emit it in the Step 7 summary.

## Model Tiering — Manager vs Workers

**Manager (you)**: the inherited root model. Do not override your own model.

**Workers**: dispatch via the `subagent` tool using the `worker` agent with an
explicit `model` override chosen by task complexity. Detect availability once
at the start of the loop:

```bash
pi --list-models codex   # check whether openai-codex/* models are present
```

Pick the worker model per task using your judgment. Do not require any specific
model — degrade gracefully:

| Task complexity | Preferred worker model | Fallback if codex unavailable |
|-----------------|------------------------|-------------------------------|
| Complex (multi-file, tricky logic, refactors) | `openai-codex/gpt-5.6-terra` | `anthropic/claude-sonnet-4-6` |
| Moderate (single feature, localized change)   | `openai-codex/gpt-5.6-terra` or `openai-codex/gpt-5.5` | `anthropic/claude-sonnet-4-6` |
| Trivial (rename, config, small fix, docs)      | `openai-codex/gpt-5.5` | `anthropic/claude-haiku-4-5` |

Rules:
- If codex models are NOT listed, silently fall back to the Claude column.
- If a preferred model errors on dispatch, retry once with the fallback model,
  then continue. Never stop the loop over a model-selection issue.
- Record the chosen worker model per task in the decision journal.

Dispatch each `worker` with `context: "fresh"` so it does not inherit your
manager context, and pass the full task context in the task string.

## Prerequisites Check

Before starting the loop, verify the environment:

```bash
hive hc list --status open   # confirm tasks exist
git status                   # confirm clean working tree
git branch --show-current    # confirm on a feature branch (never main)
```

If the working tree is dirty, stash it automatically (`git stash push -u -m
hc-loop-autostash`), note it in the decision journal, and continue. Do NOT ask.

If on `main`, create a feature branch automatically — do NOT stop and ask:

1. Determine the branch name from context:
   - If an epic or task ID was given: run `hive hc show <id>` and extract the
     title. Lowercase it, strip punctuation, replace spaces with hyphens, take
     the first 4–5 meaningful words. Prefix with `feat/`. Example: "Add timers
     table migration" → `feat/add-timers-table-migration`.
   - If `--all` or no args: use the title of the first open task from
     `hive hc list --status open` the same way.
2. Run: `git checkout -b <branch-name>`
3. Continue the loop on the new branch.

If no open tasks exist, report that and stop (this is a hard no-op, not a
question).

## Step 1: Select Tasks

**If an epic ID was given** (e.g., `hc-ngmspm9i` — a parent with children):
- Run `hive hc list --parent <id> --status open` to get all open child tasks
- Skip any tasks marked `[blocked]`

**If a task ID or comma-separated list was given** (e.g., `hc-42` or
`hc-42,hc-43`):
- Use those specific task IDs

**If `--all` was given**:
- Run `hive hc list --status open` to get all open tasks
- Check parent/child hierarchy — skip tasks with open blockers

**If `--limit N` was given**:
- Take the first N unblocked tasks from `hive hc list --status open`

**Default (no args)**:
- Run `hive hc list --status open`
- Use all open, unblocked tasks (same as `--all`) — do NOT ask the user to pick

## Step 2: Build Context for Each Task

For each selected task, gather:

1. **Task details**: `hive hc show <id>` — full description, acceptance
   criteria, labels
2. **Recent git history**: `git log --oneline -15`
3. **Relevant files**: Based on the task description, identify and read the
   files most likely affected
4. **Test command**: Determine the correct test runner. Check `mi --ls` first,
   then fall back to `task test`, `go test ./...`, `bun test`, etc.
5. **Lint command**: Determine the correct lint runner (`task lint`,
   `golangci-lint run`, etc.)
6. **Complexity assessment**: Classify the task as trivial / moderate / complex
   to pick the worker model (see Model Tiering).

## Step 3: Dispatch Worker Sub-Agents

Spawn a `worker` sub-agent for each task via the `subagent` tool with the
chosen `model` override and `context: "fresh"`. Wait for it to report back
before proceeding.

Dispatch tasks **sequentially** — one at a time — since workers share the same
working tree.

### Worker Task Prompt

Fill in the gathered context and send it as the worker's task:

---

You are implementing hive hc task `<ID>`: `<TITLE>`

**Task Description**
`<full hive hc show output>`

**Codebase Context**
`<relevant file contents with line numbers>`

**Recent History**
`<git log output>`

**Commands**
- Run tests with: `<test command>`
- Run lint with: `<lint command>`

**Your job**
1. Mark this task in-progress: `hive hc update <ID> --status in_progress --assign`
2. Implement the task as described.
3. Run tests and lint — fix any failures before reporting back.
4. Do NOT commit — leave changes unstaged or staged but uncommitted.
5. If you hit a decision point, make a reasonable choice and note it — do NOT
   stop to ask questions.
6. Report back with:
   - Summary of changes made
   - List of files modified
   - Test and lint results
   - Any decisions made or blockers encountered

---

## Step 4: Review Each Completed Worker

When a worker returns, perform a critical code review yourself (on the manager
model). Do this directly — reviewing is manager work, not worker work.

### Automated Checks

```bash
git diff HEAD              # read every line
<test command>             # must pass
<lint command>             # must pass
```

### Review Checklist

- [ ] Changes are scoped to the task — no unrelated modifications
- [ ] No introduced security vulnerabilities
- [ ] Error cases handled at system boundaries (not deep in business logic)
- [ ] No over-engineered abstractions for a single use case
- [ ] No TODO/FIXME left in new code
- [ ] Existing tests still pass; new tests added for non-trivial logic
- [ ] Follows codebase naming and structure conventions

### Decision

**APPROVE**: All checks pass and review is clean.

```bash
git add -p                              # stage only task-related changes
git commit -m "<clear message>"
hive hc update <id> --status done       # mark task done
```

**REVISE**: Minor issues a worker can fix. Resume/redispatch the worker with
specific feedback and the required changes. Limit to 2 revision cycles. If
still not right after 2 cycles, decide autonomously: either commit the salvage-
able portion, or REJECT — do not ask the user.

**REJECT / SKIP**: Fundamental design issue, scope creep, or two failed
revisions.

```bash
git checkout -- .                        # discard changes
git stash drop 2>/dev/null || true       # clean any worker stashes
hive hc update <id> --status blocked     # or --status open with a note
```

Record the reason in the decision journal and **continue to the next task**.
Do not stop the loop.

## Step 5: Commit Message Format

```
<imperative summary, max 72 chars>

- <what changed and why, bullet point per file/area>
- <any non-obvious decisions>

closes hc-<id>
```

## Step 6: Continue Until Done

After each task, immediately proceed to the next selected task. Keep going
until the entire selected set is processed. Do not summarize per-task or wait
for acknowledgement between tasks.

## Step 7: Loop Summary

After all tasks are processed, report once:

```
Loop complete.
- Dispatched: N tasks
- Committed:  N tasks (list with commit hashes + worker model used)
- Revised:    N tasks (list)
- Skipped/Blocked: N tasks (list with reasons)

Decision journal:
- <task-id>: <decision> — <reason>
- ...

Remaining open: <hive hc list --status open count>
```
