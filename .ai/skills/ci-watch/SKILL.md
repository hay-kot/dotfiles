---
name: ci-watch
description: >
  Monitor CI and review comments for the current branch's PR. Use with /loop to
  automatically fix failing CI checks or address PR review comments at a set interval.
  Trigger when the user says "watch CI", "monitor my PR", "fix CI in a loop",
  "babysit my PR", "keep an eye on CI", or similar phrases. Exits cleanly when
  CI passes and no unresolved comments remain.
allowed-tools: "Bash(bash:*),Bash(gh:*),Bash(tea:*),Bash(teaapi:*),Bash(git:*),Read,Edit,Task(*)"
argument-hint: "[PR_NUMBER]"
---

# CI Watch

Monitor a PR's CI and review comments. Each loop iteration takes exactly one action
(fix CI, address comments, or exit) and lets the loop re-fire to re-check.

## Step 1: Fetch PR Status

Run the status script, passing the PR number if one was provided as an argument:

```bash
bash ~/.claude/skills/ci-watch/scripts/pr-status.sh [PR_NUMBER_IF_PROVIDED]
```

Parse the JSON output. If the script exits non-zero or produces invalid JSON, print
the raw output and exit.

## Step 2: Check PR State

Read `pr_state` from the JSON:

- `no_pr` → print "No open PR found for current branch." and **exit**
- `closed` or `merged` → print "PR #{pr_number} is {pr_state}. Nothing to watch." and **exit**

## Step 3: Act on `action_needed`

**`none`**
Print: `PR #{pr_number} ({pr_title}): CI green, no pending comments. Done.`
Exit. (Tell the loop to stop.)

**`wait`**
Print: `PR #{pr_number} ({pr_title}): CI is {ci_status}. Waiting for results.`
List any `failing_checks` names if present.
Exit. (Loop re-fires at the configured interval.)

**`ci`**
Spawn a sub-agent with this prompt (fill in values from the JSON):

```
Fix the failing CI checks for PR #{pr_number}: "{pr_title}"

Failing checks:
{for each failing_check: "- {name}: {url}"}

Inspect the failure output at the URLs above. Identify the root cause and fix it
in the source code.

Do NOT commit. Leave changes staged or unstaged. Report:
- What was failing and why
- What you changed
- Files modified
```

**`comments`**
Spawn a sub-agent with this prompt (fill in values from the JSON):

```
Address the review comments on PR #{pr_number}: "{pr_title}"

Review comments:
{for each review_comment:
  "- {author} on {file}:{line}
     {body}
  "
}

For each comment:
1. Navigate to the file and line
2. Understand what the reviewer is asking
3. Make the change if it is correct and reasonable
4. If a comment is unclear or you disagree, note it in your report but skip it

Do NOT commit. Leave changes staged or unstaged. Report:
- Each comment and how you addressed it (or why you skipped it)
- Files modified
```

## Step 4: Review and Commit

After the sub-agent reports back:

1. Read `git diff --staged` and `git diff` to review all changes
2. If changes look correct, stage relevant files and commit:
   ```bash
   git add <files>
   git commit -m "<imperative summary of what was fixed>"
   ```
3. Print a brief summary of what was fixed/addressed
4. Exit. (Loop re-fires to re-check CI status.)

**One action per iteration.** Never fix CI and address comments in the same run.
