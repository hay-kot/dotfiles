---
name: plan-code
description: >
  Technical plan for a change: system architecture, contracts between systems,
  program design, testing seams, function signatures, and file layout. Writes to
  .hive/plans/. Use when the user wants to plan how to build something before
  implementing. Takes a design from /plan-design, a research doc, a ticket, or a
  plain description as input; none is required. For small changes use /plan-mini.
allowed-tools: "Bash(git status:*),Bash(git log:*),Bash(git diff:*),Bash(git rev-parse:*),Bash(hive:*),Bash(~/.claude/skills/research/scripts/doc-meta.sh),AskUserQuestion,Read,Write,Edit,Task(*)"
---

# Plan Code

Decide how to build the change at the level of structure and contracts. The plan
fixes the shapes; the implementer writes the bodies and picks the order of work.
Write the plan yourself -- you hold the context and the decisions.

`.hive` must be a symlink. If it is missing, run `hive drive init` -- never `mkdir`.

## Step 1: Context

Read whatever the user gives you in full: a design from `/plan-design`, a research
doc from `/research`, a ticket, or a description. None is required. If the user
points at an existing doc without a path, run `hive drive ls` to find it -- Glob
does not follow the `.hive` symlink. If a
doc's `commit` differs from HEAD, run `git diff --stat <commit>..HEAD` and re-read
the changed files that matter.

Read the code the plan will touch, and find existing patterns the change should
follow. Confirm details in the code before you rely on them.

For a change with user-visible behavior where the product side is unclear (who it
is for, what done looks like), ask, or suggest `/plan-design`. Do not invent
product decisions. For a small, self-contained change, suggest `/plan-mini`.

## Step 2: Align

Post a short summary in chat:

- **Current state** -- what exists, with `file:line` references
- **Approach** -- one paragraph
- **Decisions** -- each with its rationale and the alternatives you rejected
- **Open questions** -- anything you would otherwise have to guess

Ask the open questions with the question tool (AskUserQuestion / ask_user_question),
up to 3 at a time, with your recommendation as the first option. Ask only what the
inputs and code cannot answer. Before writing, check: what would an implementer,
reading only the plan, have to guess? Resolve it now. With no open questions, go
straight to Step 3.

## Step 3: Write the Plan

Run `~/.claude/skills/research/scripts/doc-meta.sh` for frontmatter values. Never
write placeholders.

Write to `.hive/plans/YYYY-MM-DD-description.md` using the template below.

- Keep it as short as the change allows -- about a ten-minute read. Link input docs
  instead of repeating them.
- Code blocks show contracts: interfaces, types, struct fields, and signatures in
  full, with bodies elided as `...`.
- Verification items are runnable commands or specific observable steps. When a
  design from `/plan-design` exists, use its success criteria as input for what to
  verify; no one-to-one mapping is needed. Unit tests alone don't prove the change
  works -- include integration or e2e checks where the repo has them.
- Leave out sections that do not apply. A small change may need only Program
  Design, Layout, and Verification.
- The plan has no open questions. Anything unresolved goes back to the user.

## Step 4: Independent Review (conditional)

Run one fresh-context review when the plan changes a shared contract (public API,
schema, migration, auth) or the user asks. Otherwise skip it.

Use a read-only reviewer (Claude Code: `general-purpose`; pi: `reviewer`):

```
Review the technical plan at [plan path]. Inputs: [design/research paths, if any].
Check its claims against the actual code. Report every issue with the plan section
and a file:line or reason:

- Wrong assumptions about existing code
- Duplicates code or patterns that already exist
- Contracts that break existing callers without saying so
- Seams that would not let the named tests be written
- Verification steps that can't be run as written, and missing edge cases
- Over-engineering for the stated scope

Do not rewrite the plan.
```

Fix the issues that hold up. If a fix changes a decision the user made, ask first.

## Step 5: Present

```bash
hive todo add \
  --title "Review plan: <description>" \
  --uri "review://.hive/plans/<filename>"
```

Give the user the path, a short summary of the approach, and what the review changed
(if it ran). Iterate in the same file and add an entry to `updates`.

## Plan Template

````markdown
---
type: plan
date: YYYY-MM-DD
repository: owner/repo
branch: branch-name
commit: abc1234
tags: [component, topic]
design: .hive/designs/[filename.md]       # only if one was used
research: .hive/research/[filename.md]    # only if one was used
updates:
  - YYYY-MM-DD: Initial plan
---

# [Feature/Task Name] Plan

## Overview

[What we're building and the approach, in 2-4 sentences]

## Current State

[What exists and the constraints that matter, with file:line refs]

## Architecture

[Components and how they talk to each other. Add an ASCII or mermaid diagram when
more than two components are involved.]

## Contracts

[Boundaries between systems or packages: APIs, schemas, events, CLI flags, file
formats. Full shapes. Note what stays compatible and what breaks.]

## Program Design

[Types, interfaces, and signatures. Where state lives, how errors flow.]

```go
type Store interface {
    Get(ctx context.Context, id string) (*User, error)
}

func NewService(store Store, clock func() time.Time) *Service { ... }
```

## Testing Seams

[Where tests cut in: interfaces that exist so tests can swap in fakes, injected
clocks or clients, which behavior is unit vs integration vs e2e, existing helpers
to reuse.]

## Layout

```
path/to/pkg/
  service.go      -- [purpose]
  service_test.go -- [what it covers]
  store/
    sql.go        -- [purpose]
```

## Decisions

- [Decision] -- [rationale, alternatives rejected]

## Not Doing

- [Out-of-scope item]

## Verification

- [ ] `make test` -- [what it proves]
- [ ] Manual: [specific step and expected result]

## Migration and Rollout

[Only if persisted data, deploy order, or feature flags are involved]

## References

- Similar implementation: `path/to/file.ext:line`
````
