---
name: review
description: >
  Single-pass code review of the current branch (or a diff) that routes the changes
  to relevant concerns, dispatches fresh-context reviewer sub-agents, verifies findings
  to strip false positives, and reports a ranked, evidence-backed review. Use when the
  user asks to review local changes, a branch, or a PR before it goes to humans.
argument-hint: "[base-branch]"
---

# Code Review

One orchestrated review that favors **signal over volume**. The goal is a short list of
findings a human reviewer will trust — not an exhaustive dump. A review that flags thirty
things trains the author to ignore all thirty.

**Default base branch:** `main`. If an argument is given, use it instead.

## Operating principles

1. **Signal first.** A missed nit costs nothing; a false positive costs trust. When in
   doubt about whether something is a real problem, drop it or mark it low confidence.
2. **Evidence or silence.** Every Critical/Major finding cites `file:line`, quotes the
   offending code, and gives a concrete fix. No "consider reviewing…".
3. **Route, don't blanket.** Review only the concerns the diff actually touches.
4. **Fresh eyes.** Reviewer sub-agents get clean context (see the `diff-reviewer` agent), so
   they can catch mistakes the author/orchestrator already rationalized.
5. **"Nothing blocks" is a valid result.** If a concern is clean, it returns
   `no_findings`. Do not manufacture concerns to look thorough.

## Step 1 — Gather the diff

```bash
git diff <base-branch>...HEAD          # committed changes vs base
git diff                               # unstaged changes
git diff --name-only <base-branch>...HEAD
git diff --name-only
```

Combine both diffs. Detect the primary language(s) from the changed file extensions —
this selects the language notes in Step 3.

## Step 2 — Classify and route

Classify the change shape, then pick the concerns to run. State your routing decision
(activated concerns + one-line reason each) before dispatching.

| Change shape | Typical concerns |
|--------------|------------------|
| `docs-only` | Comments only (usually skip the rest) |
| `tests-only` | Tests, Comments |
| `config/infra` | Correctness (of the config), Security if it touches auth/permissions/CI |
| `product-runtime` | All applicable concerns |
| `mixed` | Route each area independently |

### Always consider
- **Correctness** — any new/changed logic, error handling, concurrency, I/O, security-sensitive code.
- **Tests** — any executable change (including CI/build scripts).

### Conditional
- **Design** — new public APIs, new abstractions, refactors spanning multiple files.
- **Comments** — any added/modified comments or missing "why" on non-obvious code.
- **Security** — auth, tokens, secrets, input parsing, URL/path construction, SQL, dependency manifests. Never suppress for these.

**When genuinely uncertain, include the concern.** Omit only when the area is clearly
absent from the diff.

## Step 3 — Dispatch reviewer sub-agents

Run the activated concerns through the **`diff-reviewer` sub-agent** (forked/clean context,
tuned to refute-by-default). The `diff-reviewer` agent is defined once and rendered per harness
(pi: `~/.pi/agent/agents/diff-reviewer.md`; Claude Code: `~/.claude/agents/diff-reviewer.md`).

**Sub-agent dispatch is mandatory — never self-review.** The entire value of this skill is
fresh eyes: a reviewer that has not seen your reasoning can independently disagree. You,
the orchestrator, have already rationalized the diff, so your own pass cannot provide that.
Every review dispatches **at least one** `diff-reviewer` sub-agent. If dispatch genuinely fails
(agent missing or the tool errors), stop and report that — do not silently downgrade to
reviewing it yourself.

**Scale the fan-out to the diff — the floor is one, the ceiling is open.** You choose how
many agents to spawn based on size, complexity, and risk; you do not choose whether to
spawn any.

| Diff shape | Sub-agents | Verification (Step 4) |
|------------|-----------|-----------------------|
| trivial / docs / one-liner | 1 reviewer covering all activated concerns | none |
| small | 1–2 reviewers, batching related concerns | Critical only |
| medium | one reviewer per activated concern (parallel) | Major+ |
| large / cross-file / risky | per-concern, split further per file/area | Major+ skeptics |

When uncertain, dispatch **more** agents, not fewer.

Give each sub-agent ONLY:

- the concern definition below (paste the relevant subsection),
- the changed hunks relevant to that concern (not the whole repo),
- the language notes for the detected language(s),
- a one-line statement of the change's intent.

Each sub-agent must return findings in the **Finding schema** (below) or
`no_findings` / `not_applicable`. Record every dispatched agent (concern + result) — the
output template's `Reviewers dispatched` block requires it, and a review without it is
invalid.

### Concern: Correctness
Find bugs before users do. Trace the happy path, then break the sad paths.
- Logic: off-by-one, inverted condition, wrong operator, missing case.
- Errors: swallowed errors, missing context, panics in library code. Logging is not handling.
- Edge cases: nil/zero/empty, boundaries, overflow, missing map key, cancelled context, very large input.
- Concurrency: unsynchronized shared state, races, deadlocks, goroutine/task leaks.
- Resources: unclosed files/connections/bodies; cleanup on every early return.
- Security (when routed): unvalidated input, injection, path traversal, hardcoded secrets, weak randomness, missing authz.

### Concern: Design
Simple beats clever; obvious beats implicit.
- Boundaries: each unit has one describable responsibility; no upward/circular deps.
- Naming: names describe what a thing *is*/does honestly; flag `utils`/`helpers`/`manager` vagueness.
- Abstractions: interfaces/generics justified by ≥2 real consumers, not speculation.
- Helpers: single-call-site wrappers that only compress syntax → inline them.
- API surface: default to unexported; hard-to-misuse contracts.
Only raise design findings that impede change or correctness — not taste.

### Concern: Tests
Confidence, not coverage percentage.
- One test per distinct execution path; flag redundant table entries covering the same path.
- Flag tests that assert on implementation details or mocks (they break on refactor / test nothing).
- Flag flaky patterns (time.Sleep / real clocks) and missing coverage for new branches.
- Boundaries only when the code actually has boundary logic.

### Concern: Comments
Why over what.
- Remove comments that restate code, repeat the symbol name, or are decoration.
- Flag stale comments that no longer match behavior (these are bugs).
- Flag missing "why" on non-obvious decisions (magic numbers, workarounds, ordering constraints).
- Fix by renaming, not commenting, where naming is the real issue. Godoc/JSDoc on exported symbols is expected, not noise.

## Language notes

Apply the notes matching the detected language. These sharpen the concerns above and
**prevent common false positives** for each ecosystem.

### Go
- Errors: expect `fmt.Errorf("context: %w", err)`; flag dropped errors, but `_ =` on
  genuinely ignorable returns (e.g. `w.Write` in some handlers) is idiomatic — don't over-flag.
- `defer resp.Body.Close()` immediately after the nil-error check.
- Concurrency: unsynchronized map access, goroutines with no lifecycle owner, channels not
  closed by the sender. Suggest `testing/synctest` over `time.Sleep` in tests (Go 1.24+).
- Dead code: for larger changes, `deadcode -test ./...` can confirm orphaned functions —
  treat exported symbols as possible external API, not automatic dead code.
- Not-a-bug: unused struct fields set via reflection/JSON tags; interface-satisfying methods
  that look unused; `context.Context` passed but unused in a stub. Verify before flagging.

### TypeScript
- Prefer `unknown` over `any`; flag `any` that erases a real type, but generated/`.d.ts`
  and truly dynamic boundaries are acceptable.
- Async: unawaited promises, missing `await` in try/catch, floating promises in effects.
  Don't flag intentionally fire-and-forget calls that are commented as such.
- Null safety: optional chaining / nullish coalescing where values can be undefined;
  non-null assertions (`!`) that hide a real nullable.
- React (if present): missing/incorrect hook deps, state updates in render, keys on lists,
  effects without cleanup. Don't flag deps a lint rule would already own unless the diff
  disables the rule.
- Not-a-bug: type-only imports, `satisfies` usage, framework-required prop shapes.

## Step 4 — Verify findings (always on)

Before reporting, run an adversarial verification pass to kill plausible-but-wrong findings.

For every finding of severity **Major or Critical**:
1. Spawn a fresh skeptic sub-agent (use `diff-reviewer` with a refute prompt) given ONLY the
   finding, the relevant diff hunk, and the concern definition — **not** the original
   reviewer's reasoning.
2. The skeptic's job is to *refute* the finding and defaults to `refuted: true` when
   uncertain. It returns `{ refuted: boolean, reason: string }`.
3. **Drop** any finding the skeptic refutes; record it in a `Dropped in verification`
   list with the skeptic's reason so a human can reinstate it if wanted.

Findings rated **Minor** or below skip verification (verifying them costs more than they're worth).

## Step 5 — Synthesize and report

Merge reviewer outputs into one review:
- Deduplicate findings at the same location; keep one owning concern, list secondary
  concerns only if they add explanatory value.
- Prefer one precise finding over several variants of the same issue.
- Order by severity, then confidence.

### Finding schema
Each finding: **severity**, **confidence** (high/medium/low), `file:line`, one-line
problem, why it matters, concrete fix.

### Severity
| Level | Meaning | Blocks merge? |
|-------|---------|---------------|
| **Critical** | Bug, data loss, race, security hole | Yes |
| **Major** | Likely-wrong behavior or significant design/test gap | Yes, unless justified |
| **Minor** | Improvement, better naming, missing error context | Recommended |
| **Nit** | Style, optional cleanup | No |

Default to the lower severity when uncertain. A misclassified Critical erodes trust.

### Output template
```markdown
# Code Review: <branch> → <base>

_Concerns: [activated concerns + one-line reason each]_
_Reviewers dispatched: [each `diff-reviewer` sub-agent + its concern(s) + result, e.g. `Correctness → findings`, `Design → no_findings`]_

[2-3 sentence overview: what the branch does, overall quality, merge readiness.]

---

### Critical
1. **`auth.go:45` — Swallowed error hides failure** (confidence: high)
   - `if err != nil { log.Println(err) }` — caller sees success on failure.
   - Fix: `return fmt.Errorf("creating user: %w", err)`

### Major
...

### Minor
...

### Nits
...

---

### Test Coverage
[Are new code paths covered? Gaps or redundant tests?]

### Dropped in verification
[Findings a skeptic refuted, with reason — omit the section if none.]

---

### Verdict
**[APPROVE / REQUEST CHANGES / NEEDS DISCUSSION]** — [one sentence]

Critical: N | Major: N | Minor: N | Nits: N
```

## Step 6 — Save the review

Save a copy to `.hive/reviews/YYYY-MM-DD-<slug>.md` (slug from branch/scope). If `.hive/`
is not a symlink, run `hive ctx init` first — never create it as a plain directory. Always
use the lowercase `reviews/` directory so tooling can aggregate review feedback consistently.

Include frontmatter:
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

## External reviewer (optional)

For an independent second opinion from a different model, run `/review-with-codex`
alongside this skill — spawn it before Step 3 so codex reviews concurrently, then merge
its findings during Step 5 under an **External Review (Codex)** heading. Codex gets clean
context by design; do not feed it this skill's findings before it reviews (avoid
"context laundering" — a second reviewer is only useful if it can independently disagree).
