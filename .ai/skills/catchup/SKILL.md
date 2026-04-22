---
name: catchup
description: Show changes compared to base branch (defaults to main). Use when the user asks what changed, wants a summary of branch differences, or says "catch me up".
allowed-tools: "Bash(git diff:*),Bash(git log:*),Bash(git status:*),Bash(git branch:*),Read,Grep,Glob"
argument-hint: "[base-branch or additional context]"
---

# Catchup

Review what has changed compared to a base branch and provide a comprehensive summary.

## Arguments

User may provide: $ARGUMENTS

These could include:
- Base branch name (e.g., `develop`, `master`, `production`) — defaults to `main` if not specified
- Git diff options (e.g., `--stat`, `--name-only`)
- File paths (e.g., `src/components/`)
- Any other context or instructions

## Instructions

1. Run `git status` to understand the current state
2. Parse $ARGUMENTS and determine:
   - Base branch to compare against (default: `main`)
   - Any additional diff options or paths
3. Run `git diff <base-branch>...HEAD` to show changes
4. If there are no uncommitted changes, check `git log <base-branch>..HEAD` for commits
5. Summarize:
   - Files modified, added, or deleted
   - Key changes per file
   - Overall purpose and themes across the changes

## Rules

- **Read-only** — do NOT modify files or create commits
- Interpret user intent flexibly from $ARGUMENTS
