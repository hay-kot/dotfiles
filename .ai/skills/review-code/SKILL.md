---
name: review-code
description: >
  Comprehensive code review of the current branch against a base branch. Evaluates
  the diff to select relevant review dimensions, then dispatches parallel sub-agents
  for focused analysis. Use when reviewing local changes before opening a PR, or when
  the user asks for a code review.
argument-hint: "[base-branch]"
---

# Code Review

Orchestrate a review of the current branch's changes by evaluating the diff, selecting
relevant review dimensions, dispatching parallel sub-agents, then synthesizing findings
into a single cohesive report.

## Scope

Review ALL changes in the current branch compared to the base branch, including unstaged changes.

**Default base branch:** `main`
**Override:** If an argument is provided, use it as the base branch (e.g., `/review-code develop`).

## Step 1: Gather the Diff

```bash
# Get the full diff including unstaged changes against the base branch
git diff <base-branch>...HEAD

# Also capture unstaged changes not yet committed
git diff

# List changed files for context
git diff --name-only <base-branch>...HEAD
git diff --name-only
```

Combine both diffs to get the complete picture of what will differ from the base branch.

## Step 2: Evaluate and Select Review Dimensions

Read the diff and decide which review dimensions to dispatch. **Comments and Tests are
always included.** The others are conditional.

### Always Run

| Dimension | Skill | Notes |
|-----------|-------|-------|
| Comments | `review-comments` | Always run |
| Tests | `review-tests` | Always run; includes coverage for Go projects |

### Conditional — include when the signal is present

| Dimension | Skill | Include when... |
|-----------|-------|-----------------|
| Correctness | `review-correctness` | New logic, error handling, concurrency, security-sensitive code, or non-trivial control flow |
| Design | `review-design` | New public APIs, significant refactoring, new abstractions, or structural changes across multiple files |

**When uncertain, include the dimension.** The cost of a missed bug outweighs the cost
of an extra sub-agent. Omit only when the changes are clearly limited in scope (e.g.,
a pure config change, documentation-only update, or trivial rename).

State which dimensions you selected and why before dispatching.

## Optional: External Codex Review

If running alongside `/review-with-codex`, spawn codex **before** dispatching sub-agents so
both run concurrently. Follow Steps 0–3 of the `review-with-codex` skill now, then proceed
with sub-agent dispatch below. Collect codex's findings after sub-agents complete (Step 4 of
`review-with-codex`), then include them in synthesis.

## Step 3: Dispatch Sub-Agent Reviews

Spawn selected sub-agents **in parallel** using the Task tool.

**Critical:** Sub-agents do not have skills loaded automatically. Each sub-agent prompt MUST
instruct the agent to first read the skill file, then follow its instructions. Include the
full diff content in the prompt so the sub-agent has the code to review.

### Correctness (conditional)
> Read the `review-correctness` skill and follow its instructions. Review all changed code
> for logic bugs, error handling gaps, edge cases, race conditions, resource leaks, and
> security vulnerabilities. For Go projects, run `deadcode -test ./...` in the repo root
> to identify unreachable functions — do not skip this; the tool requires the full build graph.
> Return findings in the format specified by the skill.

### Design (conditional)
> Read the `review-design` skill and follow its instructions. Review all changed code for
> naming, structure, abstraction quality, API surface, boundary clarity, and coupling. Return
> findings in the format specified by the skill.

### Comments (always)
> Read the `review-comments` skill and follow its instructions. Review all comments in the
> changed code for relevance and purpose. Identify comments that restate code, are stale, or
> are missing where they would help. Return findings in the format specified by the skill.

### Tests (always)
> Read the `review-tests` skill and follow its instructions. Review all test files in the
> changed code for coverage quality, redundancy, and value. For Go projects, run
> `go test ./... -coverprofile=coverage.out -covermode=atomic && go tool cover -func=coverage.out`
> in the repo root to get per-function coverage data — do not skip this; coverage requires
> actually running the tests. Identify missing tests for new code paths. Return findings
> in the format specified by the skill.

## Step 4: Synthesize Results

After all sub-agents complete, aggregate their findings into a single review.

### Deduplication

Sub-agents may flag the same location for different reasons. When this happens:
- Merge findings for the same location into one entry
- List all applicable categories (e.g., `Correctness + Design`)
- Use the highest severity across the merged findings

## Output Format

Follow the `review-format` skill for structure and formatting. The output must include:

- A 2-3 sentence **overview**: what this branch does, overall quality, and merge readiness
- **Critical**, **Suggestions**, and **Nits** sections using the numbered list format
- A **Test Coverage** paragraph summarizing coverage gaps or redundancies
- A **Verdict** with the count summary

```markdown
# Code Review: <branch-name> → <base-branch>

_Dimensions reviewed: [list selected dimensions and one-line reason for each]_

[overview]

---

### Critical
...

### Suggestions
...

### Nits
...

---

### Test Coverage
[Summary: are new code paths covered? Any gaps or redundant tests?]

---

### Verdict

**[APPROVE / REQUEST CHANGES / NEEDS DISCUSSION]** — [one sentence justification]

Critical: N | Suggestions: N | Nits: N
```

## Guidelines

1. **Be direct** — State what's wrong and how to fix it. Skip the compliments.
2. **Prioritize** — Critical issues first. Don't bury a race condition under nits.
3. **Be specific** — Reference exact files and lines. Vague feedback is useless.
4. **Assume competence** — The author can read code. Don't explain what the code does.
5. **Suggest, don't demand** — For non-critical items, frame as suggestions.
