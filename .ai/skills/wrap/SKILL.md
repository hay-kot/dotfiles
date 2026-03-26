---
name: wrap
description: Wrap up a work session - organize commits, push branch to remote, update task state
argument-hint:
---

# Wrap - Session Wrap-Up

Wrap up a work session by organizing changes into logical commits, pushing the branch to remote, and capturing task state. Work is NOT complete until `git push` succeeds.

## Usage

```
/wrap
```

## Assumptions

- You are on a feature branch (not main). If on main, create a branch first and ask the user for a name.
- The branch is yours. Do not pull or rebase from remote unless push is rejected.
- Only update `hive hc` tasks that were explicitly worked on during this session.

## Workflow

Execute ALL steps in order.

### Step 1: Assess State

```bash
git status
git diff --stat
git log --oneline -10
```

Understand what's changed, what's staged, and what's already committed.

### Step 2: Organize and Commit Changes

If there are uncommitted changes:

1. **Review all changes**: `git diff`, `git diff --cached`, and untracked files.
2. **Skip irrelevant files**: Temporary files, scratch files, debug logs, or files unrelated to the session's work. Report what you're skipping and why (e.g., "Skipping `scratch.py` - temporary test file").
3. **Group into logical commits**: Analyze the changes and organize them into coherent units. Each commit should represent one logical change. Stage specific files per commit with `git add <files>`.
4. **Write clear commit messages**: Follow the repo's commit style. Concise messages that assume codebase familiarity.

Do NOT use `git add -A` or `git add .`. Stage specific files for each logical commit.

### Step 3: Run Quality Gates

Auto-detect the project's tooling and run checks. Check in this order of priority:

1. **CLAUDE.md / AGENTS.md**: Look for project-specific check/lint/test commands
2. **Taskfile.yml**: `task --list` — look for `check`, `lint`, `test` targets
3. **Makefile**: Look for `check`, `lint`, `test` targets
4. **mise tasks**: `mise tasks` — look for relevant targets
5. **Direct commands**: Fall back to language-specific commands (`go test ./...`, `npm test`, `cargo test`, etc.)

Run whatever applies. Fix failures before proceeding. Do not push broken code.

Skip this step if only documentation or non-code files changed.

### Step 4: Update Task State

Only for `hive hc` tasks explicitly worked on during this session:

```bash
# Mark completed tasks
hive hc update <issue-id> --status done

# Add progress notes to in-progress tasks
hive hc comment <issue-id> "Progress: <what was done>"

# Create follow-up tasks for incomplete work
hive hc create --title "Follow-up: description"
```

Skip this step entirely if no `hive hc` tasks were part of this session.

### Step 5: Push to Remote

**Determine push strategy:**

1. Check if branch has an upstream: `git rev-parse --abbrev-ref @{upstream} 2>/dev/null`
2. If no upstream: `git push -u origin <branch-name>`
3. If upstream exists: `git push`

**Force push policy:** Check `git reflog` for rebase entries during this session. If a rebase occurred, use `--force-with-lease`. Otherwise, use a normal push. Never use `--force`.

**If push is rejected** (non-fast-forward) and no rebase happened during the session, do NOT auto-rebase. Ask the user:

> Push was rejected. The remote branch has diverged. Options:
> 1. Rebase onto remote and force-push with lease
> 2. Merge remote changes
> 3. Abort and investigate

### Step 6: Verify and Report

```bash
git status
git log --oneline origin/main..HEAD
```

Confirm working tree is clean and branch is pushed to remote.

## Output Format

After completing all steps, report:

```markdown
## Wrap Complete

### Branch
`<branch-name>` -> `origin/<branch-name>`

### Commits Pushed
- [sha] commit message
- [sha] commit message

### Skipped Files
- `file` - reason

### Tasks Updated
- Done: #[id] [title]
- Commented: #[id] [title]
- Created: #[id] [title]

### Status
- Working tree: Clean
- Remote: Up to date
- Remaining open tasks: [N]
```

Omit sections that have no content.

## Critical Rules

1. **NEVER stop before pushing** - Local-only commits are lost work
2. **NEVER say "ready to push when you are"** - YOU must push
3. **NEVER skip quality gates** - Don't push broken code
4. **NEVER commit sensitive files** - Check for .env, credentials, keys
5. **NEVER pull/rebase from remote on feature branches** - Only push
6. **NEVER use `git add -A` or `git add .`** - Stage specific files per logical commit
7. **ALWAYS verify push succeeded** - Check `git status` output
8. **ALWAYS use `--force-with-lease` (never `--force`)** when force-pushing after rebase

## Error Recovery

### Push rejected (no rebase in session)

Do NOT auto-rebase. Present options to the user and wait for direction.

### Tests failing

Fix the issue, re-run tests, commit the fix, then push.

### On main branch

Ask the user for a branch name, create it, then continue with normal wrap workflow.
