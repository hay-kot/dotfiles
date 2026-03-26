---
name: review-with-codex
description: >
  Spawn codex as an independent external reviewer in a new tmux window. Codex performs a
  general PR review and publishes findings back via hive messaging. Use standalone for an
  external second opinion, or alongside /review-code to run both concurrently.
allowed-tools: "Bash(tmux:*),Bash(hive msg:*),Bash(hive session:*),Bash(git:*),Bash(mktemp:*),Bash(chmod:*),Bash(printf:*),Bash(rm:*)"
disable-model-invocation: true
argument-hint: "[base-branch]"
---

# Review with Codex

Spawn codex as an independent external reviewer in a new tmux window. Codex reviews the
current branch and publishes its findings back to this session via hive messaging.

**Default base branch:** `main`. If an argument is provided, use it instead.

## Step 0: Verify Tmux

Check that the session is running inside tmux. If not, fail immediately with a clear error.

```bash
if [ -z "$TMUX" ]; then
  echo "Error: review-with-codex requires a tmux session. Not currently in tmux."
  exit 1
fi
```

## Step 1: Gather Context

```bash
git branch --show-current          # current branch name
git diff <base-branch>...HEAD --stat  # scope of changes
hive session info --json           # get session ID
```

## Step 2: Generate Review Topic

```bash
REVIEW_TOPIC=$(hive msg topic --prefix "review")
```

Save this value. Codex will publish findings to `<REVIEW_TOPIC>.codex`. You will subscribe
to that topic in Step 4.

## Step 3: Spawn Codex in a New Tmux Window

Write a self-contained shell script to a tempfile and execute it in a new tmux window.
Using a tempfile avoids quoting problems when embedding a multi-line prompt.

```bash
REVIEW_TOPIC=<from-step-2>
BASE_BRANCH=<base-branch>
REPO_PATH=$(pwd)
BRANCH=$(git branch --show-current)

SCRIPT=$(mktemp /tmp/codex-review-XXXXXX.sh)
chmod +x "$SCRIPT"

printf '#!/bin/bash\ncd %q && codex %q\n' "$REPO_PATH" "You are performing an independent code review of branch: $BRANCH

Your workflow:
1. Review all changes against $BASE_BRANCH:
   git diff $BASE_BRANCH...HEAD
   git diff

2. Analyse for issues including but not limited to: logic bugs, error handling, edge cases,
   race conditions, resource leaks, security vulnerabilities, naming problems, design issues,
   and test coverage gaps. You are a general reviewer — be thorough across all dimensions.

3. YOU MUST publish your findings before exiting. Run this exact command:
   hive msg pub --topic $REVIEW_TOPIC.codex \"your detailed findings\"

   This is not optional. The session that dispatched you is blocked waiting for this message.
   Do not summarise to stdout and stop. Do not skip this step." > "$SCRIPT"

tmux new-window -n "review-codex" "$SCRIPT"
```

This returns immediately. Codex runs asynchronously in the new window.

## Step 4: Wait for Codex Findings

Block until codex publishes its findings (up to 1 hour):

```bash
hive msg sub --topic <REVIEW_TOPIC>.codex --wait --timeout 1h
```

The output is codex's full review. Capture it for synthesis.

## Step 5: Synthesize and Present

Read the diff directly to verify and contextualise codex's findings:

```bash
git diff <base-branch>...HEAD
git diff
```

Then produce a review report:

- Challenge vague or unsupported findings — demand specific file/line evidence
- Note issues codex caught that you would have missed
- Note issues you can see that codex missed
- Follow the `review-format` skill for structure and output format

---

## Integration with /review-code

When using both skills together, run them so codex and Claude's internal sub-agents
execute **concurrently**. The pattern:

1. **Step 2 of review-code (before dispatching sub-agents):** Run Steps 0–3 of this skill
   to spawn codex in tmux. This is non-blocking — codex starts immediately in the background.

2. **Step 3 of review-code:** Dispatch internal sub-agents in parallel as normal. They run
   concurrently with codex.

3. **Step 4 of review-code:** After internal sub-agents complete, run Step 4 of this skill
   (`hive msg sub --wait`) to collect codex's findings. By this point codex may already be
   done, so the wait is often short.

4. **Synthesis:** Merge all findings — internal sub-agents + codex — into a single report.
   Add a section identifying which issues were caught only by the external reviewer:

```markdown
### External Review (Codex)

[Issues caught by codex that internal review missed, or where codex's independent
perspective adds confidence. Note any contradictions with internal findings.]
```

Include all findings in the unified Critical / Suggestions / Nits ranking.
