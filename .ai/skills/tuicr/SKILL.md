---
name: tuicr
description: Launch tuicr TUI code review in a tmux float popup for interactive diff review
---

# tuicr - TUI Code Review

Launch `tuicr` in a tmux floating popup to interactively review local git changes.
The user reviews diffs with vim keybindings, leaves comments, then exports
structured markdown back to the agent or pushes a real PR review to GitHub.

## Usage

User says: "review my changes", "tuicr", "/tuicr", "let me review the diff"

## Workflow

1. **Determine the target directory** from context:
   - Current working directory (most common)
   - Repository the user has been editing
   - Explicit path if provided

2. **Launch tuicr in a float popup with --stdout** to capture output:
   ```bash
   tuicr-float <directory> --stdout
   ```
   **Set `timeout: 600` (10 minutes)** — the script blocks until the user exits tuicr.

3. **Process the output**:
   - If `=== TUICR INSTRUCTIONS ===` markers are present: parse and execute the review comments
   - If no instructions: tell the user to paste clipboard contents if they used `y` to copy

## Additional modes

```bash
# Review a commit range
tuicr-float <directory> -r main..HEAD --stdout

# Review a GitHub PR
tuicr-float <directory> pr 125 --stdout

# Uncommitted changes only (skip commit selector)
tuicr-float <directory> -w --stdout
```

Default (no flags) opens the commit selector, which is the preferred mode.

## Popup size

Default is 95% width × 95% height. Override with environment variables:
```bash
TUICR_POPUP_WIDTH=90% TUICR_POPUP_HEIGHT=90% tuicr-float <directory> --stdout
```

## When NOT to use

- User wants raw `git diff` output (use git directly)
- User wants non-interactive review
- Not in a git repository
