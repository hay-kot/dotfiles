---
allowed-tools: Bash(git status:*), Bash(git log:*), Bash(git diff:*)
description: Generate a concise PR description by analyzing branch changes against main
---

Analyze the git changes and create a PR description following this format:

## Purpose

Write 1-2 sentences describing what problem this solves or what feature it adds. Focus on the "why" not the "what".

Use bullets only if there are multiple distinct changes:

- Feature/fix 1
- Feature/fix 2

## Implementation

Include this section only for complex changes that need explanation. Describe:

- Key architectural decisions
- Non-obvious approaches taken
- Important files/modules modified

Use mermaid diagrams sparingly, only when they clarify complex flows.

**Guidelines:**

- Keep total description under 200 words
- Avoid implementation details obvious from the code
- Focus on reviewer context, not commit-by-commit changes
- Use present tense ("Adds X" not "Added X")
- Use markdown as a format
