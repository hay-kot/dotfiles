---
name: plan-mini
description: >
  Mini research → plan for small, self-contained changes. Use for well-scoped tasks
  like bug fixes, adding a single field, or small feature additions where the overall
  system impact is limited. Faster than /research + /plan-write — single sub-agent
  per step, no user interview, lighter output.
allowed-tools: "Bash(git status:*),Bash(git log:*),Bash(git diff:*),Bash(git rev-parse:*),Bash(git branch:*),Bash(date:*),Bash(gh:*),Bash(hive:*),Read,Write,Task(*)"
---

# Mini Plan

Produce a focused implementation plan for a small, well-scoped change. One research
agent, one planning agent, no interview loop. Proceed with reasonable assumptions and
flag gaps inline.

## When to use this vs /research + /plan-write

Use `/plan-mini` when:
- The change touches ≤ 3–5 files
- The scope is already clear (bug fix, add a field, update a handler)
- You don't need architectural discovery

Use the full workflow when the change involves cross-cutting concerns, new patterns,
or architectural decisions.

---

## Step 1: Read Mentioned Files

If the user references specific files, tickets, or docs, read them **fully** first
using the Read tool without limit/offset. Do this before spawning any agent.

---

## Step 2: Spawn Research Agent

Spawn a single **Explore** agent scoped to the affected area. Tell it exactly what
to find — don't ask it to discover scope.

**Prompt template:**
```
Find the relevant code for: [user's task description]

Locate:
- The specific files/functions that need to change
- Any related types, interfaces, or DB schema involved
- Existing patterns for [similar operations in this codebase]
- Test files for the affected code

Return:
- Exact file paths and line numbers for each finding
- One sentence per finding explaining what it is and why it's relevant
- Any constraints or gotchas visible in the code (e.g. generated files, migrations needed)
```

Wait for the agent to complete.

---

## Step 3: Spawn Plan Agent

Using the research findings, spawn a single **general-purpose** agent to write the plan.

**Prompt template:**
```
Write a concise implementation plan for: [user's task description]

Research findings:
[paste full output from Step 2]

Save the plan to: .hive/plans/[YYYY-MM-DD-short-description.md]

Use this template exactly:

---
type: plan
date: YYYY-MM-DD
tags: [relevant tags]
---

# [Task Name]

## What We're Changing

[2-3 sentences: the minimal description of what changes and why]

## Files

| File | Change |
|------|--------|
| `path/to/file.ext:line` | What changes and why |

## What We're NOT Changing

[Explicitly list anything adjacent that might seem in-scope but isn't]

## Implementation Steps

1. [Concrete step — name the function/type/query to add or modify]
2. [Next step]
3. ...

## Success Criteria

### Automated
- [ ] [Command that verifies correctness]: `make test` / `go test ./...` / etc.
- [ ] Linting passes

### Manual
- [ ] [Specific observable outcome a human can verify]

## Risks & Gotchas

- [Any migration needed, generated code to regenerate, cache to invalidate, etc.]
- Write "None" if there are no risks.

---

Requirements:
- Keep it short — this is a small change
- Every file in the Files table must have a line reference
- If you find a gap the research didn't cover, write [GAP: description] — do not guess
- Do not add phases, testing strategy sections, or architecture insights — this is a mini plan
```

Wait for the agent to complete.

---

## Step 4: Gather Metadata & Finalize

Run:
```bash
git branch --show-current
git rev-parse --short HEAD
date +"%Y-%m-%d"
```

Open the plan file and add the branch and commit to the frontmatter:
```yaml
branch: [result]
commit: [result]
```

---

## Step 5: Create Review Todo

```bash
hive todo add \
  --title "Review plan: <short-description>" \
  --uri "review://.hive/plans/<filename>"
```

---

## Step 6: Present to User

State the plan file path. Summarize the files table and implementation steps in
2–4 bullet points. Flag any `[GAP:]` items.

Ask one question only if there is genuine ambiguity that would change the approach.
Otherwise just present the plan and stop.
