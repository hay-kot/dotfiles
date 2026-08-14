---
name: pr-create-auto
description: Create a PR from current branch changes. Use when the user asks to open a PR, create a pull request, or says "pr this up".
allowed-tools: "Read,Write,Glob,Bash(git status:*),Bash(git log:*),Bash(git diff:*),Bash(gh pr:*),Bash(git push:*),Bash(git checkout:*),Bash(git branch:*),Bash(git rev-parse:*),Bash(find:*),Bash(ls:*)"
argument-hint: "[issue-tags]"
---

# PR Create

Create a pull request for the current branch. If $ARGUMENTS is provided, include those issue tags in the PR body.

This skill is the authority on PR body shape. The three-section Intent / What
changed / Why this way structure in AGENTS.md governs **commit messages** and
does not apply here.

## Workflow

1. **Assess state**: `git status`, `git log --oneline origin/HEAD..HEAD`, `git diff origin/HEAD...HEAD --stat`
2. **Create branch if needed**: if on `main`, ask the user for a branch name and create it
3. **Commit uncommitted changes** if any exist (see "Commit & PR Messages" in AGENTS.md)
4. **Push the branch**: `git push -u origin <branch>`, or `git push` if upstream is already set
5. **Find the template** (below)
6. **Write the body** (below) to a temp file
7. **Create the PR**: `gh pr create --title "<title>" --body-file <tmpfile>`

Title: imperative, ≤72 chars, and matches the repo's existing title convention
— check `gh pr list --state merged --limit 10` for whether they use
Conventional Commits prefixes.

## Step 5: Find the template

```bash
root=$(git rev-parse --show-toplevel)
find "$root" "$root/.github" "$root/docs" -maxdepth 1 -iname 'pull_request_template*' 2>/dev/null
```

GitHub accepts the file in the repo root, `.github/`, or `docs/`, in any case
variant. A `PULL_REQUEST_TEMPLATE/` **directory** means the repo has multiple
templates — list it, pick the one matching the change type, and say which you
picked.

Read the template before writing anything. If one exists, it wins over
everything in "Fallback shape" below.

## Step 6: Write the body

**Source order.** Write the body from, in priority order:

1. The commit messages on this branch (`git log origin/HEAD..HEAD`) — the
   reasoning is already there
2. The linked issue, plan doc in `.hive/`, or this session's context — why the
   work was started
3. `--stat` output, only to confirm the scope claim is accurate

Do not read the full diff to write the body. Reading the diff is what produces
diff narration, and reviewers have the diff already.

### Rendering: never hard-wrap

Applies to both paths below, and to anything reflowed out of a commit message.

Write each paragraph as **one unwrapped line**, however long, and separate
paragraphs with a blank line. GitHub renders a newline inside a paragraph as a
literal line break in PR and issue bodies, so a body wrapped at 72 or 80
columns renders as a ragged column instead of flowing prose.

Do not carry a commit body over verbatim: git shows commit text as-is, so those
are conventionally wrapped, and pasting one into a PR renders ragged. Reflow it
into single-line paragraphs first. The examples below show the PR form.

Also render, don't dump: use ``` fences for code and logs, backticks for
identifiers and paths, `> ` for quoted output, and a Markdown table if you have
tabular data. Reference issues and PRs as `#12` so GitHub links them.

### Filling a template

- Keep the headings **exactly** as written — don't add, remove, reorder, or
  rename them, and don't add a "Summary" or "Test plan" section the template
  didn't ask for.
- Answer only the question each section asks. Where a section genuinely doesn't
  apply, write `N/A — <one-line reason>` rather than manufacturing content,
  unless the template says to delete unused sections.
- `<!-- HTML comments -->` are author instructions: follow them, then strip
  them from the body.
- Checkboxes: tick only what was actually done and verified in this session.
  Never tick a box for something you didn't do.

### Fallback shape (no template)

Plain prose. No `## Summary` heading, no scaffolding, no bullet list of
changes. Lead with why the change exists; add mechanics only where they aren't
inferable from the diff.

Length is capped by the nature of the change, not its diff size:

| Change | Body |
|---|---|
| Mechanical, self-evident (rename, version bump, typo) | Empty — title only |
| Single concern | One paragraph, 2–4 sentences |
| Multi-commit feature, or a non-obvious decision | Up to 3 short paragraphs |

Issue tags from $ARGUMENTS go on their own last line (`Closes #12`).

### The cut pass

Before creating the PR, delete every sentence a reviewer would learn by
reading the diff. What survives is the body. If nothing survives, the title
alone is the correct PR.

Never include: a bullet per file, function, or commit; a "Changes" or "Files
changed" section; restatements of what a function now does; test-passing
claims for tests you didn't run.

## Examples

**Good** — a version-pin fix. Why first; the mechanical part is one clause:

```
hay-kot/hive redirects to colonyops/hive, and mise's github backend does not follow the redirect when listing releases — a fresh `mise install` 404s resolving v0.58.0. The Macs never noticed because the lockfile's download URLs were recorded post-redirect; the nightshift server resolves without the lock and caught it.

Lock entry keys renamed to match the new backend name; versions/URLs refresh on the next `mise run lock`.
```

Two paragraphs, two lines. Note the unwrapped lines — that is the shape that renders correctly.

**Bad** — same change, diff-narrated. Every line is recoverable from the diff,
the actual reason (redirects break release listing) never appears, and the
headings were invented:

```
## Summary

This PR updates the hive tool reference in the dotfiles repository.

## Changes

- Updated `mise.toml` to change the hive backend from `github:hay-kot/hive` to `github:colonyops/hive`
- Updated `mise.lock` with the new lock entry keys
- Updated `bin/hive-wrapper` to reference the new path

## Testing

Ran `mise install` and confirmed it works.
```
