---
name: diff-review
description: >
  Open the current branch's diff (or a specific PR) in Plannotator's browser-based
  code review UI and act on the returned feedback. Use when the user says "review
  my changes in plannotator", "open the diff for review", "review this PR in
  plannotator", "let me annotate the diff", or returns to a session to gate code
  the agent produced.
allowed-tools: "Bash(plannotator:*),Read"
---

# Diff Review

Open code changes in Plannotator's review UI, then act on the user's feedback in
the same conversation. Plannotator's review mode handles both the current
worktree (no args) and a specific PR (URL).

## Argument handling

`$ARGUMENTS` controls what gets reviewed:

| Argument             | Behavior                                             |
| -------------------- | ---------------------------------------------------- |
| _empty_              | Current branch's working changes vs base             |
| GitHub PR URL        | That pull request                                    |
| Gitea/Forgejo PR URL | That pull request (if Plannotator supports the host) |

Don't try to detect or resolve the current PR yourself — `plannotator review`
already inspects the worktree when called with no args. Just pass `$ARGUMENTS`
through.

## Run

```bash
plannotator review $ARGUMENTS
```

Run the command yourself. Don't ask the user to copy it into a terminal.

## After plannotator returns

- **Feedback or annotations returned** — address each one in the same
  conversation. For each comment, locate the referenced file/line, make the
  change, and summarize what was fixed. Offer to re-run review when done.
- **Approval / LGTM** — acknowledge the review passed and continue (commit,
  push, open PR, whatever the next step is).
- **No feedback returned** — the user closed the session without comment. Say
  so briefly and continue.

## Notes

- Plannotator review surfaces diff-anchored annotations; treat each one as a
  request for a specific code change, not a general suggestion.
- For deep multi-dimensional review (correctness, design, tests, comments) use
  `/review-code` instead — that runs parallel sub-agents. This skill is for the
  human-in-the-loop browser review, not automated review.
- If the user wants to gate a markdown plan or research doc instead of code,
  use `/doc-review`.
