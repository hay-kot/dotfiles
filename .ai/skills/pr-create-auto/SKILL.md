---
name: pr-create-auto
description: Create a PR from current branch changes. Use when the user asks to open a PR, create a pull request, or says "pr this up".
allowed-tools: "Bash(git status:*),Bash(git log:*),Bash(git diff:*),Bash(gh pr:*),Bash(git push:*),Bash(git checkout:*),Bash(git branch:*)"
argument-hint: "[issue-tags]"
---

# PR Create

Create a pull request for the current branch. If $ARGUMENTS is provided, include those issue tags in the PR.

## Workflow

1. **Assess state**: `git status`, `git log --oneline -10`, `git diff origin/HEAD...HEAD --stat`
2. **Create branch if needed**: If on `main`, ask the user for a branch name and create it
3. **Commit uncommitted changes** if any exist (follow the commit skill conventions)
4. **Push the branch**: `git push -u origin <branch>` or `git push` if upstream already set
5. **Check for PR template**: Look for `PULL_REQUEST_TEMPLATE.md` in the repo root or `.github/`
6. **Create the PR** with `gh pr create`

## PR Description Guidelines

**Be brief.** Reviewers will read the code — don't explain it line by line.

- 1–3 sentences for the summary, focused on *why* the change was made
- Only mention non-obvious decisions or gotchas
- Small changes = small descriptions

**Do NOT:**
- List every file or function modified
- Explain obvious code changes
- Add sections for the sake of completeness

## Format

If no `PULL_REQUEST_TEMPLATE.md` exists:

```
## Summary

<1-3 sentences on why this change was made>
```

For trivial changes, a single-line title is sufficient — no body needed.
