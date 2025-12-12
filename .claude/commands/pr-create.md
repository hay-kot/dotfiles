---
allowed-tools: Bash(git status:*), Bash(git log:*), Bash(git diff:*), Bash(gh pr:*), Bash(git push:*)
description: Create a PR either from changes
---

## Task

Create a pull request for the changes.

## Workflow

Since the repository state is unknown, you may need to:

1. Create a new branch
2. Commit code changes
3. Push the branch
4. Create the PR using the GitHub CLI

## PR Template

- If `PULL_REQUEST_TEMPLATE.md` exists in the repository, use it as the basis for your PR description
- If no template exists, keep the title and description proportional to the complexity of the changes

## Writing the Description

- Assume reviewers have context on the application and understand the general motivation for the changes
- Let the code explain _what_ is happening; focus the description on _why_ when it's non-obvious
- Highlight anything tricky, non-intuitive, or requiring special attention
- Small, straightforward changes need only a brief description

## Formatting

Mermaid diagrams and GitHub callouts (e.g., `> [!NOTE]`) are available but should be used sparingly—only when they genuinely aid understanding of complex concepts.
