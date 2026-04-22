---
name: gh-pr
description: Fetch and review comments on a GitHub PR, then plan how to address them. Use when the user references a PR number and wants to action review feedback.
allowed-tools: "Bash(gh pr:*),Bash(gh api:*)"
argument-hint: "<pr-number>"
---

# GitHub PR Review Comments

Fetch comments on PR #$ARGUMENTS, summarize them, and present a plan for addressing them.

## Instructions

1. Fetch inline code review comments:

```bash
gh api repos/:owner/:repo/pulls/$ARGUMENTS/comments --paginate | jq '.[] | {file: .path, line: .line, author: .user.login, comment: .body}'
```

2. Fetch general PR review comments:

```bash
gh pr view $ARGUMENTS --json reviews,comments
```

3. Summarize all feedback grouped by theme or file.

4. For each comment, propose a concrete action:
   - What change to make and where
   - If a comment is unclear or debatable, flag it for the user to decide

5. Present the plan and wait for approval before making any changes.
