---
name: prep-plannotator-review
description: Prepare or open an unattended Plannotator code review. The current agent reviews the change, loads draft findings into a hidden diff, and waits to open it until asked. Use when the user says "prep a Plannotator review", asks for an asynchronous review in Plannotator, wants agent findings loaded into a diff, or asks to open the prepared review.
compatibility: Requires Plannotator 0.27 or later, Python 3, and Git. GitHub PR lookup also requires an authenticated gh CLI.
---

# Prepare a Plannotator Review

Review the change in the current agent session and load the findings into a hidden Plannotator session. Do not open the browser when preparation finishes. Wait until the user returns and asks to open the review.

Do not launch a Plannotator review agent, subagent, or background coding agent. The current agent must inspect the code and produce every finding. Only the Plannotator HTTP server runs in the background.

## Select the review target

1. Use a GitHub PR or GitLab MR URL supplied by the user.
2. Otherwise, try to find the current branch's pull request:

   ```bash
   gh pr view --json url --jq .url
   ```

3. If the branch has no pull request, review the local branch against its merge base. Honor an explicit base or diff type from the user.

## Start the hidden review

Resolve `scripts/prepare_review.py` relative to this `SKILL.md`. Run the matching command from the repository being reviewed:

```bash
python3 <skill-dir>/scripts/prepare_review.py start --pr <PR_URL>
python3 <skill-dir>/scripts/prepare_review.py start --diff-type merge-base
python3 <skill-dir>/scripts/prepare_review.py start --diff-type <type> --base <ref>
```

The command records the prepared session under the Plannotator data directory and prints its startup status. The review session snapshots the comparison at startup.

## Review in this session

Perform a single-pass code review yourself. Do not delegate it.

1. Read repository guidance such as `AGENTS.md`, `CLAUDE.md`, and `REVIEW.md`.
2. Inspect the complete diff for the selected comparison.
3. Read the surrounding functions, call sites, tests, and contracts needed to verify each candidate issue.
4. Focus on defects a maintainer would fix: incorrect behavior, regressions, realistic unhandled failures, security problems with a concrete path, data loss, and broken contracts.
5. Exclude style preferences, speculative refactors, generic test requests, and findings that cannot be demonstrated from the code.
6. Use post-change file paths and line numbers. Confirm every line is part of the displayed diff. Use `side: "old"` only for deleted lines.
7. Return no findings when the change is correct. Do not invent comments to populate the UI.

For a remote PR, inspect it with `gh pr diff` and provider metadata as needed. Confirm the local checkout matches the reviewed head before using local file line numbers.

## Load findings

Write the verified findings to a temporary JSON file outside the repository. Use this shape:

```json
{
  "annotations": [
    {
      "type": "concern",
      "scope": "line",
      "filePath": "path/to/file.py",
      "lineStart": 42,
      "lineEnd": 42,
      "side": "new",
      "severity": "important",
      "text": "State the impact and the condition that triggers it.",
      "reasoning": "Explain how the code path confirms the issue."
    }
  ]
}
```

Allowed `type` values are `concern`, `comment`, and `suggestion`. Allowed `severity` values for review findings are `important`, `nit`, and `pre_existing`.

Use `concern` for defects, `comment` for non-defect context, and `suggestion` when supplying replacement code. If the user asks for a smoke test instead of a real review, use `comment` and start its text with `TEST:` so nobody mistakes it for review feedback.

Prefer line-scoped findings. If an issue applies to a whole file and has no honest line anchor, use `scope: "file"` with `filePath`. Use `scope: "general"` only when no file applies. Suggestions can include `suggestedCode`.

Post the batch to the hidden session:

```bash
python3 <skill-dir>/scripts/prepare_review.py post --input <FINDINGS_JSON>
```

The script adds the `active-agent-review` source label. An empty annotation list is valid and does not call the API. Delete the temporary findings file after a successful post. Keep it long enough to correct and retry a failed post, then delete it.

## Finish preparation

Do not open the browser after loading findings. Tell the user how many findings were loaded and that the review is ready. Do not print the session URL unless the user asks for it. Findings remain local until the user explicitly submits them in Plannotator.

When the user later asks to open the prepared review, run:

```bash
python3 <skill-dir>/scripts/prepare_review.py open
```

If review or annotation loading fails, keep the session available for inspection and report the error and log path. Show stored session details only when needed:

```bash
python3 <skill-dir>/scripts/prepare_review.py status
```

Stop the prepared session only when the user asks or when startup produced the wrong comparison:

```bash
python3 <skill-dir>/scripts/prepare_review.py stop
```

## Constraints

- Never call `/api/agents/jobs`. The active session is the reviewer.
- Never post findings to GitHub or GitLab.
- Treat all findings as drafts for the user to verify.
- Do not use `--no-local` for PRs.
- Avoid duplicate sessions. Check `plannotator sessions` before retrying an interrupted run.
