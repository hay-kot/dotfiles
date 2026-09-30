---
name: plan-mini
description: >
  Mini research → plan for small, self-contained changes. Use for well-scoped tasks
  like bug fixes, adding a single field, or small feature additions where the overall
  system impact is limited. Faster than /research + /plan-write -- no sub-agents, no
  user interview, lighter output.
allowed-tools: "Bash(git status:*),Bash(git log:*),Bash(git diff:*),Bash(git rev-parse:*),Bash(hive:*),Bash(~/.claude/skills/research/scripts/doc-meta.sh),Read,Write"
---

# Mini Plan

Research and plan a small change in one pass, in your own context. No sub-agents and
no interview loop: proceed on reasonable assumptions and flag gaps inline.

Use this when the change touches about 5 files or fewer and the scope is already
clear. Use `/research` + `/plan-write` for cross-cutting changes, new patterns, or
architectural decisions.

`.hive` must be a symlink. If it is missing, run `hive ctx init` -- never `mkdir`.

## Step 1: Investigate

Read any files, tickets, or docs the user mentions in full. Then find and read:

- The files and functions that need to change
- Related types, interfaces, or schema
- An existing example of the same kind of change, if there is one
- The tests that cover the affected code

Note constraints visible in the code: generated files, migrations, caches, flags.

If the change turns out bigger than expected (more than about 5 files, or a design
choice with real alternatives), stop and tell the user to use `/research` +
`/plan-write` instead.

## Step 2: Write the Plan

Run `~/.claude/skills/research/scripts/doc-meta.sh` for frontmatter values.

Write to `.hive/plans/YYYY-MM-DD-short-description.md`. Keep it short. Every file in
the Files table has a line reference. Where something is unknown, write
`[GAP: description]` rather than guessing. Code blocks show contracts only
(signatures and types, bodies elided as `...`).

```markdown
---
type: plan
date: YYYY-MM-DD
repository: owner/repo
branch: branch-name
commit: abc1234
tags: [relevant tags]
---

# [Task Name]

## What We're Changing

[2-3 sentences: what changes and why]

## Files

| File | Change |
|------|--------|
| `path/to/file.ext:line` | What changes and why |

## What We're NOT Changing

[Adjacent things that look in scope but aren't]

## Implementation Steps

1. [Concrete step -- name the function/type/query to add or modify]
2. ...

## Success Criteria

- [ ] `make test` / `go test ./...` -- [what it proves]
- [ ] Linting passes
- [ ] Manual: [specific observable outcome]

## Risks & Gotchas

[Migrations, generated code, caches to invalidate. "None" if none.]
```

## Step 3: Finish

```bash
hive todo add \
  --title "Review plan: <short-description>" \
  --uri "review://.hive/plans/<filename>"
```

Give the user the plan path, a 2-4 bullet summary of the files and steps, and any
`[GAP:]` items. Ask a question only if the answer would change the approach.
