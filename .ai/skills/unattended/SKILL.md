---
name: unattended
description: Continue the current task without user input while the user is away. Use only when invoked directly.
disable-model-invocation: true
allowed-tools: "Bash(~/.claude/skills/enable-push/scripts/push.sh:*)"
---

# Unattended mode

Work independently until the exit condition passes or no useful work remains.

## Before you start

- State the exit condition as a check that can pass or fail: a command, a test, a repro, or an artifact you can inspect. A duration ("keep going for two hours") is not an exit condition. If the task gives none, derive the narrowest one that matches the task and state it.
- Turn on push notifications. Read the `enable-push` skill (`~/.claude/skills/enable-push/SKILL.md`) and follow it for the rest of the session, unless it is already on.

## While you work

- Do not wait for user input. Make conservative, reversible decisions and continue.
- Work in small units and verify each one against the real artifact before you start the next. Keep a change only when the evidence shows it helped. When evidence refutes a hypothesis, revert the changes it motivated.
- Unblock yourself by trying reasonable alternatives, fixing failures, and skipping optional blocked steps. A plateau is not a stop: change the approach. Never relax the exit condition to declare success.
- Keep implementing, testing, and documenting even if a commit, push, credential, approval, or external service is unavailable.
- If commit signing is blocked, leave the changes uncommitted. Never disable or bypass signing.
- Do not perform destructive, irreversible, security-sensitive, or externally visible actions without prior authorization.

## Decision trail

The push notifications and the final response are the audit trail. Keep a running list of decision points: a fork you chose, an assumption the user may reverse, a pivot or revert and what triggered it, a blocker. Note what you decided, why, and the evidence (a commit, a `file:line`, a command and its output).

- Send an `update` push for each assumption the user may want to reverse and each finding that changes the plan or scope, as `enable-push` describes. Routine progress does not get a push.
- End with a final response that has, in order: the exit condition and whether it passes, with the evidence; the decision trail; blockers, assumptions, skipped steps, and unfinished work. Then send the closing `done`, `blocked`, or `failed` push.
- Do not claim completion while the exit condition fails or required work remains blocked.
