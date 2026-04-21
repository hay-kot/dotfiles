---
name: research
description: >
  Research codebase comprehensively using parallel sub-agents. Use when the user asks
  for deep research, wants to understand how a feature works, or needs thorough analysis
  of patterns and architecture across the codebase.
allowed-tools: "Bash(git status:*),Bash(git log:*),Bash(git diff:*),Bash(git rev-parse:*),Bash(git branch:*),Bash(date:*),Bash(gh:*),WebSearch,Read,Write,Task(*),TodoWrite"
---

# Research Codebase

Conduct comprehensive research across the codebase by spawning parallel sub-agents and
synthesizing their findings into a research document.

## Scope Constraint

You are a documentarian, not a critic. Describe what exists, where it exists, and how
it works. DO NOT suggest improvements, identify problems, or recommend changes unless
the user explicitly asks. This constraint applies to all sub-agents you spawn.

## Context Directory

Research documents are stored in `.hive/research/` managed by `hive ctx`.

**IMPORTANT:** `.hive` must be a symlink, not a directory. If it doesn't exist, run
`hive ctx init` to create it — NEVER use `mkdir`.

## Step 1: Read Mentioned Files

If the user mentions specific files (tickets, docs, JSON), read them **fully** first
using the Read tool WITHOUT limit/offset parameters. Do this before spawning any sub-tasks.

## Step 2: Decompose the Research Question

Break down the query into composable research areas. Identify:
- Specific components, patterns, or concepts to investigate
- Which directories, files, or architectural patterns are relevant
- Cross-component connections and architectural implications

Then use **TodoWrite** to record the decomposition as a task list — one item per
sub-agent — before spawning anything. This makes the research plan visible and
correctable before expensive work begins.

## Step 3: Spawn Parallel Sub-Agent Tasks

Create multiple Task agents to research different aspects concurrently.

Strategy:
- Start with **codebase-locator** agents to find what exists
- Follow up with **codebase-analyzer** agents on the most promising findings
- Only spawn **web-concepts-researcher** or **web-implementations-researcher** when
  the question warrants external context
- Run multiple agents in parallel when searching for different things
- Tell agents **what** to look for, not **how** to search

Each agent type must return structured YAML, not free-form prose:

```yaml
# codebase-locator returns:
files:
  - path: string
    line: int           # anchor line, if applicable
    relevance: high|medium|low
    rationale: string   # one sentence
gaps:
  - string              # areas searched but not found

# codebase-analyzer returns:
findings:
  - file: string
    line_range: "start-end"
    pattern: string
    confidence: high|medium|low
    evidence: string    # one sentence quote or description
open_questions:
  - string

# web-concepts-researcher returns:
# Focus: official docs, specs, architectural theory, canonical patterns.
# Search: documentation sites, RFCs, language specs, primary sources.
sources:
  - url: string
    title: string
    key_insight: string
gaps:
  - string

# web-implementations-researcher returns:
# Focus: real-world usage, known pitfalls, Stack Overflow, GitHub issues,
# blog case studies, version-specific gotchas.
sources:
  - url: string
    title: string
    key_insight: string
gaps:
  - string
```

## Step 4: Synthesize Findings

Wait for **all** sub-agents to complete before proceeding.

- Prioritize live codebase findings as primary source of truth
- Use `.hive/` as supplementary historical context
- Connect findings across components
- Include specific file paths and line numbers
- Collect all `gaps` from sub-agent outputs for the Open Questions section

## Step 5: Gather Metadata

Before writing the document, run all of these and record the actual values:

```bash
git branch --show-current
git rev-parse --short HEAD
date +"%Y-%m-%d"
gh repo view --json nameWithOwner -q .nameWithOwner
git config user.name
```

**NEVER proceed with placeholder values.** If a command fails, re-run it or ask the
user. A document with `[branch]` or `abc1234` as its commit hash is worse than no
document.

## Step 6: Write the Research Document

**Filename format:** `.hive/research/YYYY-MM-DD-description.md`
- With ticket: `2025-01-08-ENG-1478-parent-child-tracking.md`
- Without ticket: `2025-01-08-authentication-flow.md`

Write the **TL;DR section last**, after all other sections are complete.

```markdown
---
type: research
date: YYYY-MM-DD
repository: owner/repo
branch: branch-name
commit: abc1234
tags: [component, topic]
topic: "exact research question verbatim"
agents_used:
  - codebase-locator
  - codebase-analyzer
confidence: high|medium|low
confidence_rationale: "one sentence explaining the confidence level"
updates:
  - YYYY-MM-DD: Initial research
---

# Research: [Topic]

**Date**: YYYY-MM-DD
**Researcher**: [git config user.name]
**Commit**: [short hash]
**Branch**: [branch]
**Repository**: owner/repo

## Research Question

[Original query verbatim]

## TL;DR

[2-3 sentences. Written last — summarize the most important finding and its
implication. Optimized for a 10-second human scan.]

## Key Findings

- Finding with source reference (`file.ext:line` or URL)
- Each bullet must cite a source — no unsourced claims
- Connection to other components if relevant

## Decisions

[Decisions made during or after this research. Update this section if the user
communicates a decision while the research is in progress.]

## Open Questions

[Real unknowns the research could not resolve — sourced from sub-agent `gaps` outputs.
Not rhetorical questions.]

## Detailed Findings

### [Component/Area 1]

- Finding with reference (`file.ext:line`)
- Connection to other components
- Implementation details

### [Component/Area 2]

...

## Architecture Insights

[Patterns, conventions, and design decisions discovered]

## Historical Context

[Relevant insights from `.hive/` directory]

## Resources

### Code

- `path/to/file.go:123` — description
- `path/to/other.go:45-67` — description

### Related Documents

- [[YYYY-MM-DD-related-research-slug]] — one-line description
- [[YYYY-MM-DD-related-plan-slug]] — one-line description

### URLs

- https://... — description
```

## Step 6a: Create Review Todo

After writing the research document, create a todo for human review:

```bash
hive todo add \
  --title "Review research: <topic-slug>" \
  --uri "review://.hive/research/<filename>"
```

## Step 7: Add GitHub Permalinks (if applicable)

If on main or a pushed branch, replace local `file:line` references in the Resources
section with GitHub permalinks:

```bash
gh repo view --json owner,name
```

Format: `https://github.com/{owner}/{repo}/blob/{commit}/{file}#L{line}`

## Step 8: Present Findings

Summarize key findings concisely to the user. Include file references for navigation.
Ask if follow-up questions or clarification is needed.

## Step 9: Handle Follow-up Questions

Append follow-up research to the same document:
- Append a new entry to the `updates` list in frontmatter: `- YYYY-MM-DD: [brief description]`
- Add a new section: `## Follow-up Research [timestamp]`
- Spawn new sub-agents as needed

## Important Notes

- Always run fresh codebase research — never rely solely on existing research documents
- Read mentioned files FULLY before spawning sub-tasks
- Wait for ALL sub-agents to complete before synthesizing
- Gather metadata before writing — NEVER use placeholder values
- Keep the main agent focused on synthesis, not deep file reading
- Sub-agents return structured YAML — not prose summaries, not raw tool output
- Check `.hive/` for existing research and context; if reusing a prior document,
  compare its `commit` to current HEAD (`git rev-parse --short HEAD`) and note
  staleness if they differ
- Related Documents links use Obsidian wiki-link syntax: `[[filename-without-extension]]`
