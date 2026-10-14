---
name: triage-renovate
description: Triage open Renovate pull requests in the current GitHub repository, fix broken updates, and group the results by merge readiness. Run only when explicitly invoked.
argument-hint: "[PR_NUMBER ...]"
disable-model-invocation: true
---

# Triage Renovate pull requests

Inspect the current GitHub repository's open Renovate pull requests. Fix safe,
well-understood failures and push those fixes to the pull request branches. Review
large or risky updates and return one grouped Markdown report.

Never run this skill because a general request happens to mention Renovate. Run it
only through its explicit command.

## Arguments

`$ARGUMENTS` can contain pull request numbers. When numbers are present, inspect
only those pull requests after verifying that Renovate opened them. With no
arguments, inspect every open Renovate pull request in the current repository.
Reject other argument forms rather than treating them as shell input.

## Boundaries

- Work only in the current repository.
- Support GitHub repositories through `gh`. Stop with a clear message on another
  forge.
- Never merge, approve, close, or convert a pull request.
- Never post comments, edit pull request text, change labels, or request reviews.
- Never change Renovate configuration as a shortcut for fixing an update.
- Never disable a check, delete a test, weaken an assertion, or pin the dependency
  back to its previous version to make CI pass.
- Do not force-push. If a repair requires rewritten history, put the pull request in
  `Need Human Review`.
- Follow the repository's agent instructions, contribution rules, task runner, and
  signed-commit requirements.
- Treat changes that existed before this command as user work. Do not stage, edit,
  stash, reset, or clean them.

## 1. Validate the repository

1. Resolve the Git root and confirm that `origin` points to GitHub.
2. Confirm that `gh auth status` succeeds and that `gh repo view` resolves the
   current repository.
3. Record the current branch and status for the final report.
4. Run `mi --ls` when available so repository tasks take precedence over ad hoc
   test commands.
5. Fetch `origin` without pruning or changing the checked-out branch.

Do not require a clean main worktree. Each repair must use an isolated temporary Git
worktree so the user's current branch and files remain untouched.

## 2. Find Renovate pull requests

List open pull requests with enough data to assess ownership, CI, and merge state:

```bash
gh pr list --state open --limit 100 \
  --json number,title,url,author,isDraft,headRefName,baseRefName,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,additions,deletions,changedFiles,labels,updatedAt
```

A pull request belongs to Renovate only when the normalized author login is one
of these known identities:

- `app/renovate-sh-app` or `renovate-sh-app[bot]` for the current Renovate GitHub App
- `app/renovate`, `renovate`, or `renovate[bot]` for older installations

GitHub's REST and GraphQL APIs can return different forms for the same app. Accept
the forms above, but do not identify ownership from the title or branch name alone.

If explicit pull request numbers were supplied, load each with `gh pr view` and
apply the same author check. Report and skip a number that is closed, missing, or
not owned by Renovate.

For every selected pull request, also load its body, file list, head repository,
and head branch:

```bash
gh pr view <number> --json body,files,headRefName,headRepository,headRepositoryOwner,isCrossRepository,maintainerCanModify
```

## 3. Establish status and risk

Classify CI from the checks attached to the current head commit:

- `failing`: any required or reported check has a failure, error, timeout,
  cancellation, startup failure, or action-required result
- `pending`: at least one check is queued or in progress and none failed
- `passing`: checks exist and every completed check passed, was neutral, or was
  skipped
- `missing`: no checks are reported

Also record merge conflicts, a requested-changes review, draft state, an unknown
merge state, and branch-protection blocks. Do not call a pull request ready from
CI alone.

### Risk signals

Put a pull request in `Need Human Review` when the update has any unresolved signal
below, even when CI passes:

- a semantic-version major update or release notes that describe breaking changes
- database migrations, persisted-data formats, schemas, serialization, generated
  clients, or wire protocols
- authentication, authorization, cryptography, secrets, permission, or security
  policy behavior
- a public API or CLI contract change that downstream users can observe
- a runtime, compiler, operating-system baseline, deployment platform, or storage
  engine change
- a new or unfamiliar direct dependency whose maintenance, provenance, license,
  or install behavior cannot be established
- grouped updates where one failing or risky dependency cannot be assessed
  independently
- required manual migration or rollout steps
- behavior that tests cannot cover with reasonable confidence

A large diff triggers deeper review, but size by itself does not require human
review. Treat a pull request as large when it has at least 500 changed
non-generated lines, at least 20 non-generated files, or updates multiple direct
dependencies. Exclude lockfiles, checksums, vendored trees, and generated files
when applying the numeric thresholds.

### Review large and risky updates

For each large or risk-signaled pull request:

1. Read the full dependency diff and the Renovate release notes in the pull request
   body.
2. Identify the old and new versions and whether the update is patch, minor, major,
   digest-only, or grouped.
3. Follow upstream release-note or migration-guide links when the pull request body
   does not explain compatibility. Prefer primary upstream sources.
4. Search the repository for affected APIs and configuration keys.
5. Check lockfile changes for unexpected packages, sources, install scripts, or
   dependency-graph expansion.
6. Run focused tests or validation when the review depends on runtime behavior.
7. Record the exact risk or the evidence that clears it. Do not use vague text such
   as "large change, please review."

## 4. Repair broken pull requests

A pull request needs repair when CI fails, it has a merge conflict, or its requested
changes can be resolved with a repository change. Process repairs sequentially.
Keep one pull request's files, tests, and commits isolated from every other pull
request.

### Create an isolated worktree

For pull request `<number>`:

1. Create a temporary directory outside the repository.
2. Fetch `refs/pull/<number>/head` from `origin`.
3. Add a detached worktree at the fetched commit. A detached worktree avoids local
   branch-name collisions.
4. Read the repository instructions again from inside the worktree before editing.
5. Remove the worktree after a successful push. If a push fails after a valid
   commit, preserve the worktree and report its path and commit SHA.

Equivalent commands are:

```bash
tmp=$(mktemp -d "${TMPDIR:-/tmp}/triage-renovate-<number>.XXXXXX")
git fetch origin "refs/pull/<number>/head"
git worktree add --detach "$tmp" FETCH_HEAD
```

### Diagnose before editing

- Use `gh pr checks <number>` to identify failed checks.
- Read failed job logs with `gh run view <run-id-or-url> --log-failed` when the
  failure came from GitHub Actions.
- Reproduce the failure locally when practical.
- Compare against the pull request's base branch to distinguish update breakage
  from a failure already present on the base branch.
- If the base branch has the same failure, do not change the dependency pull
  request. Report the shared failure under `Need Human Review`.

### Make only safe repairs

A repair is safe when the failure has a clear cause, the change is limited to the
compatibility work required by the dependency update, and repository validation
covers the changed behavior. Typical safe repairs include:

- regenerating a lockfile or generated dependency metadata with the repository's
  pinned toolchain
- adapting a removed or renamed API at existing call sites
- updating mocks, fixtures, or tests to an intentional upstream contract
- resolving a simple merge conflict whose correct result is unambiguous

Stop and classify the pull request as `Need Human Review` when the repair changes a
data model, public behavior, security boundary, migration, architecture, or rollout
plan, or when more than one reasonable repair exists.

For an unambiguous merge conflict, merge the current remote base branch into the
pull request worktree, resolve it, validate it, and create a normal merge commit.
Do not rebase or force-push.

### Validate, commit, and push

1. Run the smallest focused check while iterating.
2. Before committing, run the repository's relevant formatter, linter, generated
   file check, and test tasks. Use `mi` tasks when available.
3. Review the complete diff and confirm it contains no unrelated files.
4. Create a signed commit. Follow the repository's commit-message rules and explain
   why the dependency update needs the compatibility change.
5. Push `HEAD` to the pull request's existing head branch. For a same-repository
   branch, push to `origin`. For a fork, push to the reported head repository only
   when existing permissions allow it.
6. Record the pushed commit SHA. Never use `--force` or `--force-with-lease`.
7. Re-query the pull request and its checks. Wait up to 15 minutes for a terminal CI
   result, then continue. A timeout is not a failure; report it as pending.

If validation fails, do not commit or push. Discard the temporary repair worktree
unless preserving it would help a human continue. If preserved, report its path and
why it is useful.

## 5. Categorize every selected pull request

Each pull request must appear exactly once:

### Ready to Merge

Use this only when all checks pass, GitHub reports the pull request mergeable with
no blocking merge state, it is not a draft, no changes are requested, and the risk
review found no reason for human judgment. A missing check suite is not passing.

### Fixed

Use this when this run pushed a tested repair. Include the commit SHA and the latest
CI state. Keep it here when CI is still pending so the report distinguishes work
completed in this run from untouched pull requests.

If CI fails again after the pushed repair, move it to `Need Human Review` and state
what still fails.

### Need Human Review

Use this for risk signals, unresolved failures, blocked pushes, ambiguous repairs,
merge conflicts that are not safe to resolve, changes-requested reviews that need
judgment, missing required tests, or updates whose compatibility cannot be
established.

### Waiting

Use this for untouched pull requests whose CI is pending, whose merge state is
still being calculated, or whose draft status is the only blocker. Include this
section only when needed.

## 6. Report

Return Markdown in chat only. Do not create a report file or tracking issue. Use
this shape and include `None` for an empty required category:

```markdown
# Renovate triage: owner/repository

Reviewed N open Renovate pull requests. Fixed X. Y need human review.

## Ready to Merge
- [#123 Update example to v1.2.3](url) - CI passes; patch update; no risk signals found.

## Fixed
- [#124 Update library to v4](url) - Pushed `abc1234` to adapt the removed API; CI pending.

## Need Human Review
- [#125 Update database driver to v3](url) - Major update changes timestamp serialization. Confirm stored-data compatibility before merge.

## Waiting
- [#126 Update tool to v2.4.1](url) - CI is still in progress.
```

For each item, state the evidence that controls its category: latest CI state,
merge blocker, repair commit, or concrete review risk. End with a short note if the
original main worktree had pre-existing changes and confirm that the skill left
them untouched.
