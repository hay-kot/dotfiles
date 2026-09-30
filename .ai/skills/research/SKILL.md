---
name: research
description: >
  Research how a codebase works today and write a factual research doc to
  .hive/research/. Use when the user asks for deep research, wants to understand how
  a feature works, or needs analysis of patterns and architecture across the codebase.
  Fans out parallel sub-agents only when the question spans several areas.
allowed-tools: "Bash(git status:*),Bash(git log:*),Bash(git diff:*),Bash(git rev-parse:*),Bash(gh:*),Bash(hive:*),Bash(~/.claude/skills/research/scripts/doc-meta.sh),WebSearch,Read,Write,Task(*)"
---

# Research Codebase

Produce a factual map of the code as it exists today, saved to `.hive/research/`. The
output feeds `/plan-write`, so it records facts, not proposals.

## Scope Constraint

You are a documentarian, not a critic. Describe what exists, where, and how it works.
Do not suggest improvements or changes unless the user asks. Sub-agents follow the
same rule.

`.hive` must be a symlink. If it is missing, run `hive ctx init` -- never `mkdir`.

## Step 1: Read Mentioned Files

Read any files the user mentions (tickets, docs, JSON) in full before anything else.
Run `hive ctx ls` to see existing research. If you reuse a prior doc, compare its
`commit` to HEAD and treat changed areas as unverified.

## Step 2: Write the Research Questions

Turn the request into 3-8 concrete questions about the current code: which components
handle X, how data flows from A to B, what patterns exist for Y, where tests live.
Phrase them as questions about what exists, not about the feature being built -- an
agent that knows the goal starts forming opinions instead of collecting facts.

Post the questions to the user in one short message, then continue without waiting.

## Step 3: Investigate

For each question, pick the cheaper path:

- **Answer it yourself** when a few searches and reads cover it.
- **Delegate to a sub-agent** when it needs reading many files (roughly 10+), or when
  3+ questions cover independent areas. Run them in parallel, at most 4.

Agents to use:

| Need | Claude Code | pi |
|------|-------------|----|
| Codebase exploration | `codebase-analyzer` (or `Explore`) | `scout` |
| External docs, issues, prior art | `web-search-researcher` | `researcher` |

Use web agents only when the question depends on external behavior (library
semantics, API contracts, known bugs).

Give each sub-agent its questions, the relevant paths if known, and this return
format. Do not pass the ticket or the intended change.

```
## Findings
- `path/to/file.ext:12-40` -- what exists and how it works (one or two sentences)

## Gaps
- What you searched for and did not find
```

## Step 4: Gather Metadata

```bash
~/.claude/skills/research/scripts/doc-meta.sh
```

Use its values in the frontmatter. Never write placeholder values. If `pushed: yes`,
write links in Resources as
`https://github.com/{repository}/blob/{commit_full}/{file}#L{line}`.

## Step 5: Write the Document

Path: `.hive/research/YYYY-MM-DD-description.md` (prefix a ticket ID when there is
one, e.g. `2026-01-08-ENG-1478-parent-child-tracking.md`).

Keep it to the facts the planner needs -- usually under 300 lines. Every finding cites
a `file:line` or URL. Leave out sections that have nothing in them. Write the TL;DR
last.

```markdown
---
type: research
date: YYYY-MM-DD
repository: owner/repo
branch: branch-name
commit: abc1234
author: Name
tags: [component, topic]
topic: "research request verbatim"
confidence: high|medium|low
confidence_rationale: "one sentence"
updates:
  - YYYY-MM-DD: Initial research
---

# Research: [Topic]

## Research Question

[Original request verbatim, then the numbered questions from Step 2]

## TL;DR

[2-3 sentences for a 10-second scan]

## Key Findings

- Finding with source (`file.ext:line` or URL)

## Detailed Findings

### [Component/Area]

- How it works, with `file.ext:line` references and connections to other areas

## Patterns and Conventions

[Patterns a new change in this area would be expected to follow, with examples]

## Decisions

[Decisions the user states during the research]

## Open Questions

[Real unknowns, from your own gaps and sub-agent Gaps]

## Resources

- `path/to/file.go:123` -- description
- [[YYYY-MM-DD-related-doc-slug]] -- related `.hive/` doc
- https://... -- external source
```

## Step 6: Finish

```bash
hive todo add \
  --title "Review research: <topic-slug>" \
  --uri "review://.hive/research/<filename>"
```

Give the user the doc path, the TL;DR, and the open questions.

For follow-ups, append a `## Follow-up: [topic]` section to the same doc and add an
entry to `updates` in the frontmatter.
