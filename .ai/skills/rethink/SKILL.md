---
name: rethink
description: >
  Post-implementation design re-evaluation. After a feature reaches a working state
  through iteration, step back and re-examine what actually got built: are the data
  structures and algorithms the right fit for the access patterns that emerged, can
  code paths that grew through iteration be consolidated, and what iteration residue
  (tests for abandoned designs, dead flags/scaffolding, debug logging) should be
  deleted. Produces a tiered proposal report and applies only approved changes. Use
  when the user says "rethink this", "step back and re-evaluate", "is this the right
  design/data structure", "apply CS fundamentals", or wants a design pass on a working
  feature branch before PR. Not for bug-hunting (/review) or expression-level polish
  (/simplify) — this questions the design those skills preserve.
argument-hint: "[base-branch]"
---

# Rethink

Iterating to a working state optimizes for *reaching green*, not for design. The shape
the code lands in is the shape of the search path, not necessarily the shape of the
problem. This skill re-derives the design from the now-known requirements and proposes
the diff between what iteration produced and what you would build knowing what you
know now. Behavior stays fixed; design is negotiable.

**Default base branch:** `main`. If an argument is given, use it instead.

## Operating principles

1. **Behavior is fixed; design is negotiable.** Tests define the contract and stay
   green. Everything else — data structures, algorithms, path topology, test suites
   themselves — is open to question. Behavior *gaps* discovered along the way are
   flagged in the report, never designed or patched here.
2. **Fresh eyes are mandatory.** You (the orchestrator) iterated to this design, so
   you have already rationalized it. Every lens below runs as a sub-agent that gets
   the code and the intent, not your reasoning. Never self-review.
3. **"The design is sound" is a success, not a failure.** Do not manufacture
   proposals to look thorough — a false restructuring proposal costs far more than a
   missed one.
4. **Deletion beats restructuring.** The cheapest improvement is removing iteration
   residue. Prefer proposals that end with less code.
5. **Scope is the feature and its blast radius.** The changed files plus what calls
   into them. No repo-wide crusades; pre-existing sins outside the feature are out of
   scope unless the feature made them worse.
6. **Chesterton's fence.** Before calling something accidental, check git history and
   comments for evidence it is deliberate. "I don't see why this exists" is a research
   prompt, not a finding.
7. **Proposals, not patches.** Report first, get approval, then change code. Design
   changes are exactly the changes an agent should not make silently.

## Preconditions

- The implementation works and the test suite passes. If not, stop — this skill
  re-evaluates working designs; it is not a debugger.
- Work is committed (a revertible baseline exists and a SHA range is available). If
  there are uncommitted changes, commit them first or ask.

## Step 1 — Establish scope and intent

```bash
git merge-base <base-branch> HEAD        # base SHA
git diff --stat <base>...HEAD            # changed files
git log --oneline <base>...HEAD          # iteration history — read it; it shows the search path
```

Also check `hive ctx ls` for a plan or research doc for this feature. If history was
squashed or rewritten, skip the archaeology — the lenses fall back to reference
analysis (who calls what today), which is the stronger evidence anyway.

Write a short **intent statement**: what the feature must do, stated as requirements,
not as a description of the current implementation. Two rules keep it honest:

- Every requirement needs evidence *outside the implementation* — the user's ask, a
  plan/design doc, the README, or behavior a consumer demonstrably relies on. The
  implementation exposing a capability does not make that capability a requirement;
  writing an artifact into the intent statement makes it unquestionable to every lens.
- State requirements at the level the evidence supports, no finer. An over-specified
  intent statement manufactures findings against phantom requirements.

Then list the **blast radius**: files outside the diff that call into or consume the
changed code.

## Step 2 — Dispatch the three lenses (parallel, fresh context)

Spawn one read-only sub-agent per lens (general-purpose; instruct: read and analyze
only, change nothing). Give each ONLY: the intent statement, the changed-file list and
SHA range, the blast radius list, its lens brief below, and this sentence verbatim:
*"Returning `design-sound` with no findings is a successful outcome; do not manufacture
findings to look thorough."* Do not include your own opinions or candidate suspects —
a seeded lens confirms your hypothesis instead of forming its own. Each lens returns
findings in the schema (Step 4) or `design-sound`.

Collect all lens results before moving to Step 3. If a lens fails or its result is
lost, re-dispatch it once; if that also fails, run that one lens yourself as a
separate, self-contained pass and mark it self-reviewed in the report.

### Lens A — Data structures & algorithms

First inventory the operations the code actually performs on its data: lookups by key,
membership tests, ordered iteration, repeated scans, priority selection, range queries,
deduplication, synchronization between parallel collections — and, for concurrent code,
the synchronization structure itself (what one lock covers vs. what actually contends).
Then, for each core structure, ask whether the chosen representation serves those
operations or whether the code is compensating — linear searches where a map would do,
re-sorting per call, parallel collections kept in sync by hand, flags encoding what a
state machine would make explicit, recomputation where the result is stable.

Propose a change only when it deletes compensating code or changes complexity class on
an input that can realistically grow. State the expected input scale, name the
replacement precisely (map keyed by X / heap ordered by Y / interval tree / precomputed
index / state machine with states S1..Sn), and give before/after complexity when it is
the point. A structure swap that keeps the same amount of code and only wins
theoretical Big-O on n≤100 is not a finding.

### Lens B — Code paths

Trace each major path end to end: entry point → transformations → effects. Look for
topology that records the iteration history rather than the problem: two paths doing
overlapping work because they evolved from different attempts and were never merged;
data round-tripping through conversions (parse → stringify → parse); pass-through
layers with one caller that only forward; conditionals guarding states that can no
longer occur; the same decision re-made at multiple depths. The test for each: if this
were written today from the intent statement, would this path exist in this shape?

If the intent statement names a known next feature, also check whether the shapes on
these paths can bear it — a mismatch is reported as a behavior gap (flagged, not
designed), not as a restructuring.

### Lens C — Iteration residue

Hunt what earlier iterations left behind, inside scope: tests that exercise interfaces
or behaviors that no longer exist, or that pin implementation details of a superseded
approach; exported symbols whose only in-repo callers are tests — "kept for the
future" needs a documented commitment (plan, issue, README), and even with one it goes
in the report as a keep-or-cut decision rather than passing silently; feature flags or
config keys with only one live value; debug logging and timing code; helpers whose
last real caller left; defensive handling for inputs that can no longer arrive;
TODO/FIXME comments referring to already-resolved questions.

Evidence rules: residue is proven by reference — nothing live calls it — with git
history as supporting color when available. A comment or test asserting that some
*external* consumer exists is a claim, not proof; report the item with that claim
stated as an unverified assumption and let the owner adjudicate.

## Step 3 — Merge, then skeptic pass

First **merge convergent findings**: when multiple lenses hit the same code, combine
into one finding, keep both lens attributions, and treat the convergence as
corroborating evidence. One skeptic per merged finding, not per duplicate.

Findings are design *proposals*, so verification means arguing the other side:

- **Residue deletions** — verify mechanically: nothing in or out of scope references
  the item; the "stale" test genuinely asserts nothing about live behavior. Evidence
  attached, no skeptic agent needed. If the item is exported API, note that deletion
  is a breaking change for external consumers and carry that into the report.
- **Restructuring proposals (Lens A/B)** — for each, spawn a fresh skeptic sub-agent
  with the proposal, the relevant code, and the intent statement — not the lens's
  reasoning. Its brief: argue the current design should stay (change risk, hidden
  requirements the shape encodes, the win being smaller than claimed). The skeptic
  returns one of: **uphold** (proposal stands), **demote** (real but not now — move to
  Worth discussing or Later), **drop** (defense wins), with reasons; partial verdicts
  are allowed and recorded. Before accepting a demote or drop, check for a free
  fragment: if part of the proposal costs nothing — no contract change, no new state,
  no added code — that part is recommended now even when the rest is deferred.
- If sub-agents are unavailable, run each skeptic as its own self-contained pass and
  say so in the report — a self-run skeptic is weaker than a fresh one.

## Step 4 — Report

Each surviving finding: `file:line` · lens(es) · current shape (one sentence) ·
proposed shape (contracts/signatures only, bodies elided) · case for (the CS or
consolidation argument) · case against (from the skeptic, kept honest) · effort.
Delete-list items carry their reference evidence instead of a skeptic case-against.
Effort: **S** = one file, mechanical, tests untouched; **M** = crosses files or changes
signatures, tests updated; **L** = reshapes a core structure or path, staged commits.

Assemble tiers:

```markdown
# Rethink: <branch>

_Intent: [the intent statement]_
_Lenses: A → n findings, B → design-sound, C → n findings. Merged: n. Skeptic: n upheld / n demoted / n dropped._

## Adopt before merge
[Clear wins, low risk — typically deletions and small consolidations]

## Worth discussing
[Real trade-offs — restructurings with a credible case both ways]

## Delete list
[Residue with reference evidence, safe to remove now; breaking-change note if exported]

## Out of scope (behavior gaps)
[Missing capabilities or feature-fit mismatches discovered while re-deriving — flagged
for the owner, deliberately not designed here. Omit if none.]

## Later
[Valid but not worth doing before this merge]

## Dropped by skeptic
[Proposal + reason — omit if none]

**Verdict:** [SOUND / SOUND WITH CLEANUP / RESHAPE RECOMMENDED] — one sentence.
```

If all lenses return `design-sound` and the delete list is empty, say so in three
lines and stop. That outcome is the skill working, not failing.

Save the report to `.hive/reviews/YYYY-MM-DD-rethink-<slug>.md` (if `.hive/` is
missing, run `hive ctx init` — never mkdir). Frontmatter: `type: rethink`, date,
branch, commit, base_branch, tags.

## Step 5 — Gate and apply

Present the report summary and stop for direction. Apply only what the user approves:

- Delete-list items first — cheapest wins, and they shrink the surface the
  restructurings must preserve.
- One restructuring at a time, each in its own commit, never mixed with behavior
  changes. Full test suite green after each. Structural commits get a `refactor:`
  prefix.
- After each restructuring, compare honestly: if the result is not clearly better
  than what iteration produced, revert it and note why in the report.
