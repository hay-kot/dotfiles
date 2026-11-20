---
name: plan-design
description: >
  Work out what to build before how: who it is for, the experience, how success is
  measured, what it looks like, and what is out of scope. Iterates with the user in
  short question rounds and writes a design to .hive/designs/. Use when the user
  wants to define the UX, success criteria, or scope of a feature before technical
  planning. Not for team proposal docs (/design-doc) or technical design (/plan-code).
allowed-tools: "Bash(git status:*),Bash(git log:*),Bash(git diff:*),Bash(git rev-parse:*),Bash(hive:*),Bash(~/.claude/skills/research/scripts/doc-meta.sh),AskUserQuestion,Read,Write,Edit"
---

# Plan Design

Agree with the user on what to build and why it matters. Stay out of the how:
architecture, contracts, signatures, and file layout belong to `/plan-code`.

`.hive` must be a symlink. If it is missing, run `hive drive init` -- never `mkdir`.

## Context

Read whatever the user gives you in full: a ticket, a rough idea, a research doc,
screenshots. If the user points at an existing doc without a path, run
`hive drive ls` to find it -- Glob does not follow the `.hive` symlink. Then look at
the product only as far as the design needs it -- current flows, UI or CLI
conventions, the terms users already see. This is not a research pass. If the user
wants one, they will run `/research`.

## Interview

Work in rounds. Each round:

- A few lines on what you now understand, and what changed since the last round.
- Up to 3 questions with the question tool (AskUserQuestion / ask_user_question).
  Ask only what needs the user's judgment: who it is for, which flow matters most,
  trade-offs between options, where scope ends. Never ask what the input or the
  product already answers.
- When you have a recommendation, make it the first option. When an answer
  contradicts an earlier one or grows the scope, say so once, then go with the
  user's call.

Cover these, skipping any that do not apply:

- **Problem and users** -- who hits this and what they do today
- **Experience** -- the main flow from the user's side, plus the states that matter
  (empty, error, first run)
- **Success** -- how we know it worked: behavior someone can observe, and metrics if
  they exist
- **Look** -- see Mockups below
- **Out of scope** -- adjacent things that look in scope but are not

When the doc would read as what the user wants, propose writing it. The user can
keep going.

## Mockups

Sketch only when there is a surface a user sees, and keep it small and inline:

- **UI** -- an ASCII wireframe of the key screen or state
- **CLI** -- example commands with their output
- **API, config, library** -- an example request and response, config file, or call
  site

Skip mockups for internal changes with no visible surface. For in-depth visual
exploration (several HTML options, rounds of revision) suggest `/mockups` to the
user rather than building it here.

## Write

Run `~/.claude/skills/research/scripts/doc-meta.sh` for frontmatter values. Never
write placeholders.

Write to `.hive/designs/YYYY-MM-DD-description.md`. Leave out sections with nothing
in them. Open Questions holds only what the user chose to defer.

````markdown
---
type: design
date: YYYY-MM-DD
repository: owner/repo
branch: branch-name
commit: abc1234
tags: [component, topic]
research: .hive/research/[filename.md]   # only if one was used
updates:
  - YYYY-MM-DD: Initial design
---

# [Feature] Design

## Problem

[Who hits it, what they do today, why that is not good enough]

## Experience

[The main flow from the user's side, and the states that matter]

## Mockups

[ASCII wireframes, CLI transcripts, or example requests]

## Success Criteria

- [Observable outcome or metric]

## Out of Scope

- [Item] -- [why]

## Decisions

- [Decision] -- [rationale]

## Open Questions

- [Deferred question]
````

## Finish

```bash
hive todo add \
  --title "Review design: <description>" \
  --uri "review://.hive/designs/<filename>"
```

Give the user the path and a short summary. Iterate in the same file and add an
entry to `updates`.
