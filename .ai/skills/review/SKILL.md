---
name: review
description: >
  Proof-backed code review of the current branch, a diff, or a PR. Restates the
  intent, checks the diff against its spec or plan, looks for breakage beyond the
  diff, and keeps a blocking finding only when a command proves it. Use when the
  user asks to review local changes, a branch, or a PR before it goes to humans.
argument-hint: "[base-branch | PR number]"
disable-model-invocation: true
---

# Code Review

A review a human can trust without replaying it. Reviewers try to break the change, and a blocking finding survives only when a command shows the failure.

## Operating principles

1. **Proof or it is not blocking.** Critical and Major findings need a command that ran against the real code and printed the failure: a failing test, a repro script, a crafted input, command output. A finding you can only argue for goes under Unproven, with what would prove it.
2. **Signal over volume.** A missed nit costs nothing; a false positive costs trust. "No verified findings" is a valid result. Do not manufacture concerns to look thorough.
3. **Fresh eyes.** Reviewers are sub-agents that have not seen your reasoning. Never review the diff yourself in their place.
4. **Hands off the user's tree.** Reviewers run and write repros only in the review worktree. The review applies no fixes.

## Evidence levels

Every finding carries the highest level it reached:

1. **Asserted** -- someone said so. Never reported.
2. **Pointed** -- a real `file:line` (or the library's own source) shows the problem.
3. **Traced** -- the failing path walked step by step, from input to wrong result.
4. **Ran** -- a command against the real code fails the way the finding says.
5. **Reproduced** -- the failure shows in the running app. When the repo has a `verify-<app>` skill, use it.

Critical and Major need level 4 or 5. Level 3 goes under Unproven. Design and Comments findings are never blocking: they cap at Minor and need level 2.

## Step 1 -- Scope, intent, spec

**Scope.** Default base branch `main`; an argument replaces it. For a branch, the scope is `git diff <base>...HEAD` plus uncommitted changes. For a PR number, fetch it with `git fetch origin pull/<n>/head` and review that commit against its base. Detect the languages from the changed files.

**Intent.** Restate in two to four plain sentences what the change is for and what must stay true. Build it from the user's message, the commits, the PR description, the plan, and the `hive hc` task the work tracks. If the intent is unclear and the user is present, ask. Otherwise state your assumption in the report.

**Spec.** Look for the document the change implements: a plan or design in `.hive/plans/` or `.hive/designs/` (run `hive drive ls`; Glob does not follow the symlink) that matches the branch or topic, the `hive hc` task, the PR's linked issue, or a path the user gave. With none, report "no spec" and skip the Spec concern.

## Step 2 -- Review worktree

Reviewers need a copy of the change they can run and write into:

```bash
dir="${TMPDIR:-/tmp}/review-<slug>"
git worktree add --detach "$dir" <head>        # HEAD, or the fetched PR commit
git diff HEAD | git -C "$dir" apply            # uncommitted tracked changes (branch scope only)
git ls-files --others --exclude-standard       # copy these untracked files into "$dir"
```

Find the repo's test command (`mi --ls`, then the language default), install dependencies in the worktree if it needs them, and run the tests once. Note what already fails: a failure present before any repro is not a finding of this review.

A finding is a regression only when its repro passes on the base. When that is in doubt, check it in a second worktree at `git merge-base <base> <head>`. A bug the base already has goes in a one-line Pre-existing list.

## Step 3 -- Route

Classify the change, then pick the concerns. State the routing (each concern and a one-line reason) before you dispatch.

| Change shape | Typical concerns |
|--------------|------------------|
| `docs-only` | Comments, Spec (usually skip the rest) |
| `tests-only` | Tests, Comments |
| `config/infra` | Correctness of the config, Blast radius, Security if it touches auth, permissions, or CI |
| `product-runtime` | All applicable concerns |
| `mixed` | Route each area on its own |

Always run Correctness, Tests, and Blast radius for executable changes, and Spec when a spec exists. Run Design, Comments, and Security when the diff touches their area; never skip Security for auth, secrets, input parsing, path or URL construction, SQL, shell commands, or dependency manifests. When in doubt, include the concern.

## Step 4 -- Dispatch reviewers

Run the concerns through the `diff-reviewer` sub-agent, defined once and rendered per harness (Claude Code: `~/.claude/agents/diff-reviewer.md`; pi: `~/.pi/agent/agents/diff-reviewer.md`). Every review dispatches at least one. If dispatch fails, stop and report it; do not review it yourself instead.

| Diff shape | Sub-agents |
|------------|-----------|
| trivial, docs, one-liner | 1 reviewer for all concerns |
| small | 1-2 reviewers, related concerns batched |
| medium | one reviewer per concern, in parallel |
| large, cross-file, risky | per concern, split further by file or area |

Give each reviewer, in Mode A:

- the concern definition below, pasted in full,
- the intent from Step 1, and the spec path for the Spec concern,
- the changed hunks for its concern,
- the worktree path, the test command, and the tests that already fail,
- a unique repro prefix, such as `review-correctness-`, for any file it writes.

Record every dispatched reviewer and its result for the report.

### Concern: Correctness
Find bugs before users do. Trace the happy path, then break the sad paths.
- Logic: off-by-one, inverted condition, wrong operator, missing case.
- Errors: swallowed errors, missing context, panics in library code. Logging is not handling.
- Edge cases: nil, zero, empty, boundaries, overflow, missing map key, cancelled context, very large input.
- Concurrency: unsynchronized shared state, races, deadlocks, leaked goroutines or tasks.
- Resources: unclosed files, connections, or bodies; cleanup on every early return.
Prove each finding with a test or script that calls the changed code with the breaking input.

### Concern: Spec
Hold the diff against the spec. Quote the spec line for each finding.
- Requirements the spec asks for that are missing or partial.
- Behavior the diff adds that the spec did not ask for.
- Requirements that look implemented but behave wrong. Prove these with a run.
Missing and unrequested behavior need level 2: the spec line and the `file:line`.

### Concern: Blast radius
Find what the change breaks outside the diff. Listing callers is not the job; grep does that in a second.
- Find the one fact the change is safe because of (for example, "this call only drops cache entries that are already dead"). Prove it with a script that runs the real code, or report it as unproven.
- Look where grep stops: the source of the library at its pinned version and any local patch, wire formats, JSON an API returns, database columns, another language reading the same bytes, feature flags, config, lifecycle and timing order, code a few hops downstream.
- Report each risk with how it breaks, the `file:line`, how likely and how bad, and the check. List what you checked and cleared.

### Concern: Security
Treat every input as hostile until the code proves otherwise.
- Injection: SQL, shell, and template injection; path traversal from unvalidated input.
- Secrets: hardcoded credentials; tokens or secrets in logs, errors, or URLs.
- Authz: missing or bypassable permission checks on new endpoints, handlers, or commands.
- Randomness: predictable generators used for tokens, ids, or anything guessable.
- Dependencies: new or changed manifest entries, unpinned versions, unfamiliar packages, install scripts.
Prove with a crafted input against the real code where you can. Never send it to a live external system.

### Concern: Tests
Confidence, not coverage percentage.
- New branches and changed behavior with no test.
- Tests that assert on mocks or internals, or that pass by construction (the expected value computed the way the code computes it).
- Flaky patterns: sleeps, real clocks, shared global state.
Prove a weak test by breaking the code it covers in the worktree and showing the test still passes. Revert that change afterwards.

### Concern: Design
Simple beats clever; obvious beats implicit. Raise only what impedes change or correctness, never taste.
- Boundaries: each unit has one describable responsibility; no upward or circular dependencies.
- Abstractions: interfaces and generics justified by two or more real consumers, not speculation.
- Wrappers with one caller that only compress syntax: inline them.
- API surface: unexported by default; contracts hard to misuse.

### Concern: Comments
Why over what.
- Comments that restate code, repeat the symbol name, or decorate.
- Stale comments that no longer match behavior. These are bugs.
- Missing "why" on non-obvious decisions: magic numbers, workarounds, ordering constraints.
Doc comments on exported symbols are expected, not noise.

## Step 5 -- Verify

Do not trust a pasted output. For every level 4 or 5 finding, rerun its exact command in the worktree yourself. Keep the finding when the output shows the failure and the failure breaks the intent. Otherwise drop it, with the reason.

For a level 3 finding a reviewer rated Major or Critical, spawn a fresh `diff-reviewer` in Mode B with only the finding, its hunk, and the concern definition. A refuted finding goes to Dropped; a surviving one goes to Unproven.

Merge findings that share a root cause. Minor and Nit findings skip verification.

## Step 6 -- Report

```markdown
# Code Review: <branch> -> <base>

**Intent:** <the restatement>
**Spec:** <path or task id, or "none">
_Concerns: <each concern and a one-line reason>_
_Reviewers dispatched: <each reviewer, its concerns, and its result>_

<two or three sentences: what the change does and whether it is ready to merge>

### Critical
1. **`auth.go:45` -- Swallowed error hides failure** (level 4, verified)
   - Problem and why it matters.
   - Proof: `go test ./auth -run TestCreateUserError` printed `expected error, got nil`; the intent requires the caller to see the error.
   - Fix: `return fmt.Errorf("creating user: %w", err)`

### Major
### Minor
### Nits

### Unproven
<level 3 findings: the traced path, and the command that would prove or clear it>

### Blast radius
<the one fact the change is safe because of, its level, and its proof or "unproven"; risks are findings above; then what was checked and cleared>

### Pre-existing
<one line each; omit when empty>

### Dropped
<findings dropped in verification, with the reason; omit when empty>

### Before you merge
<the cheapest repro or test that guards the worst finding, with its path in the worktree>

### Verdict
**APPROVE / REQUEST CHANGES / NEEDS DISCUSSION** -- one sentence.
Critical: N | Major: N | Minor: N | Nits: N | Unproven: N
```

Default to the lower severity when unsure.

| Severity | Meaning | Blocks merge? |
|-------|---------|---------------|
| **Critical** | Bug, data loss, race, security hole | Yes |
| **Major** | Wrong behavior, spec gap, or test gap that hides a bug | Yes, unless justified |
| **Minor** | Improvement, naming, missing error context, design | Recommended |
| **Nit** | Style, optional cleanup | No |

## Step 7 -- Save and clean up

Copy the repro scripts worth keeping into the report's "Before you merge" section. Then remove the worktrees with `git worktree remove --force "$dir"`.

Save the report to `.hive/reviews/YYYY-MM-DD-<slug>.md` (slug from the branch or scope). If `.hive` is not a symlink, run `hive drive init` first; never create it as a plain directory. Use the lowercase `reviews/` directory so tooling can aggregate reviews.

```yaml
---
type: review
date: YYYY-MM-DD
repository: owner/repo
branch: <branch>
commit: <HEAD hash>
base_branch: main
tags: [component, topic]
---
```

## Step 8 -- Post inline in Hive Desktop

In a hive session, also put the findings on the branch diff. Hive Desktop shows them inline in the session's Changes view. The user dismisses the ones they disagree with and sends the rest, with their own comments, to the session's agent. Do this only when the review covered the session's own branch against its base. Skip it for a PR or another diff, because the line numbers will not match.

```bash
hive review diff put <<'JSON'
{
  "author": "claude",
  "summary": "<overview sentence> Verdict: REQUEST CHANGES.",
  "comments": [
    {"path": "auth.go", "startLine": 45, "severity": "issue",
     "text": "Swallowed error: the caller sees success on failure. Proof: go test ./auth -run TestCreateUserError printed 'expected error, got nil'. Fix: return fmt.Errorf(\"creating user: %w\", err)"}
  ]
}
JSON
```

- Set `author` to your agent's name (`claude`, `pi`, ...).
- Write one comment per finding. Map severity: Critical and Major to `issue`, Minor to `suggestion`, Nit and Unproven to `note`. Start an Unproven comment with "Unproven:". Leave out dropped and pre-existing findings.
- Line numbers count the branch's version of the file. Add `endLine` for a range. For removed code, add `"startSide": "deletions"` and use the base's line numbers. For a whole-file comment, use `"kind": "file"` with no lines.
- Write `text` for the agent that will act on it: the problem, the proof, and the fix.
- A later put from the same `author` replaces the earlier review, so always put the whole review.
- A refused review stores nothing and lists each comment to fix. Fix those and put again.
- The `diff_review_put` tool on the `hive-drive` MCP server takes the same fields plus `caller`.
- If the command answers `not in a hive session`, skip this step.
