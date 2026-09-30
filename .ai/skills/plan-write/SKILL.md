---
name: plan-write
description: >
  Create an implementation plan from a research document. Use when the user wants to
  plan a feature, task, or ticket before implementing. Expects a research doc from
  /research as input. Aligns with the user on design and structure first, then writes
  a plan of vertical slices to .hive/plans/.
allowed-tools: "Bash(git status:*),Bash(git log:*),Bash(git diff:*),Bash(git rev-parse:*),Bash(hive:*),Bash(~/.claude/skills/research/scripts/doc-meta.sh),AskUserQuestion,Read,Write,Task(*)"
---

# Implementation Plan

Turn a research doc into a plan an implementation agent can execute without guessing.
You write the plan yourself -- you already hold the research and every decision, so
handing drafting to a sub-agent only costs a re-read. Most of the value comes from
aligning with the user in Steps 2-3, before the plan exists.

`.hive` must be a symlink. If it is missing, run `hive ctx init` -- never `mkdir`.

## Step 1: Read the Research

Read the research doc in full. If none was given, run `hive ctx ls` and ask which to
use. If there is none at all, suggest `/research` first.

If the doc's `commit` differs from HEAD, run `git diff --stat <commit>..HEAD` and
re-read any changed files the plan will touch.

Read the files the plan will change. The research tells you where to look; confirm
the details before you rely on them.

## Step 2: Design Discussion

Post a short design summary in chat:

- **Current state** -- what exists, with `file:line` references
- **Desired end state** -- what is true when this is done, and how to observe it
- **Patterns to follow** -- existing code this change should match, with references
- **Decisions** -- choices you made from the research, one line of rationale each
- **Open questions** -- anything you would otherwise have to guess

Ask the open questions with the question tool (AskUserQuestion / ask_user_question).
Only ask what the research and code cannot answer: design alternatives, scope
boundaries, business rules, compatibility needs.

Before moving on, check: what would an implementer, reading only the plan, have to
guess? Resolve each answer with the user now.

## Step 3: Structure Outline

Propose the phases as **vertical slices**. Each slice cuts through the layers it needs
and leaves something that runs and can be tested. Avoid horizontal plans (all schema,
then all services, then all API) -- they defer every failure to the end.

For each phase, give its name, what works at the end of it, and how that is verified.
Include the new or changed signatures and types -- the plan's header file.

Get explicit approval before writing the plan. If the user has already agreed to the
design and there were no open questions, you can post Steps 2 and 3 together.

## Step 4: Write the Plan

Run `~/.claude/skills/research/scripts/doc-meta.sh` for frontmatter values. Never
write placeholders.

Write to `.hive/plans/YYYY-MM-DD-description.md` using the template below.

- Keep it as short as the change allows. A reviewer should read it in about ten
  minutes. Do not repeat the research doc -- link it.
- Code blocks show contracts: interfaces, types, struct fields, and signatures in
  full, with function bodies elided as `...`.
- Every verification item is a runnable command or a specific observable step.
- Each phase names the tests it adds. Unit tests alone don't prove a slice works --
  include integration or e2e tests where the repo has them.
- Leave out template sections that don't apply.
- The plan contains no open questions. Anything unresolved goes back to the user.

## Step 5: Independent Review (conditional)

Run one fresh-context review when the plan has 4+ phases, changes a shared contract
(public API, schema, migration, auth), or the user asks for it. Otherwise skip it.

Use a read-only reviewer (Claude Code: `general-purpose`; pi: `reviewer`):

```
Review the implementation plan at [plan path], based on the research at [research path].
Check its claims against the actual code. Report every issue you find, with the
plan section and a file:line or reason:

- Wrong assumptions about existing code
- Duplicates code or patterns that already exist
- Phases that don't leave something runnable and verifiable
- Verification steps that can't be run as written, and missing edge cases
- Over-engineering for the stated scope

Do not rewrite the plan.
```

Fix the issues that hold up. If a fix changes a decision the user made, ask first.

## Step 6: Present

```bash
hive todo add \
  --title "Review plan: <description>" \
  --uri "review://.hive/plans/<filename>"
```

Give the user the plan path, the phase list, and what the review changed (if it ran).
Iterate on feedback in the same file and add an entry to `updates`.

## Plan Template

````markdown
---
type: plan
date: YYYY-MM-DD
repository: owner/repo
branch: branch-name
commit: abc1234
tags: [component, topic]
research: .hive/research/[source-filename.md]
updates:
  - YYYY-MM-DD: Initial plan
---

# [Feature/Task Name] Implementation Plan

## Overview

[What we're building and why, in 2-4 sentences]

## Current State

[What exists and the constraints that matter, with file:line refs. Link the research
doc for the rest.]

## Desired End State

[What is true when done, and how to observe it]

## Decisions

- [Decision] -- [rationale]

## What We're NOT Doing

- [Out-of-scope item]

## Phase 1: [Name]

[What works at the end of this phase]

### Changes

**`path/to/file.ext`** -- [summary]

```go
type Store interface {
    Get(ctx context.Context, id string) (*User, error)
}

func (s *SQLStore) Get(ctx context.Context, id string) (*User, error) {
    ...
}
```

### Verification

- [ ] `make test-X` -- [what it proves]
- [ ] Manual: [specific step and expected result]

**Checkpoint:** stop for human confirmation before Phase 2.

---

## Phase 2: [Name]

...

## Migration and Rollout

[Only if persisted data, deploy order, or feature flags are involved]

## References

- Research: `.hive/research/[filename]`
- Similar implementation: `path/to/file.ext:line`
````
