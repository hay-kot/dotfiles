---
name: review-format
description: Standard template and structure for code review output. Use when producing review findings to ensure consistent, actionable, evidence-backed feedback.
---

# Review Output Format

Every review must follow this structure. Do not invent alternative formats.

## Severity Levels

| Level | Meaning | Requires Action? |
|-------|---------|-----------------|
| **Critical** | Bug, data loss, race condition, security vulnerability | Yes — must fix before merge |
| **Suggestion** | Design improvement, missing error context, better naming | Recommended |
| **Nit** | Style, minor naming preference, optional cleanup | Optional |

**Default to the lower severity when uncertain.** A misclassified Critical erodes trust in the review.

## Template

```markdown
# Code Review: [scope or branch]

Iteration [N] of [M] | Focus: [skill focus for this iteration]

---

### Critical

1. **`auth.go:45` — Swallowed error discards failure context**
   - Evidence: `if err != nil { log.Println(err) }` — error not returned to caller
   - Fix: `return fmt.Errorf("creating user: %w", err)`

### Suggestions

1. **`user.go:88` — `formatName` helper only called once**
   - Evidence: Single call site at handler.go:32
   - Recommendation: Inline the 2-line body and delete the helper

### Nits

1. **`cache.go:12`** — Comment restates code: `// increment counter` above `count++`

---

### Verdict

**[SHIP / DO NOT SHIP / NEEDS DISCUSSION]** — [One sentence. If SHIP: note any conditions. If DO NOT SHIP: name the blocking issue(s).]

Critical: N | Suggestions: N | Nits: N
```

## Saving the Review

After outputting the review, save a copy to `.hive/Reviews/` using the filename pattern
`YYYY-MM-DD-<slug>.md` where the slug is derived from the branch or scope name.

```bash
mkdir -p .hive/Reviews
```

Then write the file with the Write tool. If `.hive/` does not exist as a symlink, run
`hive ctx init` first — never create it as a plain directory.

Every saved review must include this frontmatter:

```yaml
---
type: review
date: YYYY-MM-DD
repository: owner/repo
branch: [branch reviewed]
commit: [HEAD commit hash]
base_branch: main
tags: [component, topic]
---
```

## Evidence Requirements

Every **Critical** and **Suggestion** finding must include:

1. **File and line number** from the diff — no vague "somewhere in auth.go"
2. **Quoted or described code** that demonstrates the problem
3. **A concrete fix** — not "consider improving" or "think about refactoring"

Findings that cannot cite specific evidence belong at **Nit** severity or should be dropped.

## Iterative Review Rules

When a previous review exists, apply these rules before writing:

1. **Validate each prior finding** — find its evidence in the diff. If you can't, downgrade to Nit or drop it.
2. **Promote or demote** — a finding with strong evidence from your skill focus can be upgraded; weak evidence downgrades.
3. **Add new findings** — from your skill focus this iteration.
4. **Consolidate, don't append** — the output is a single coherent review, not a chain of critiques. Rewrite entries, do not stack them.
