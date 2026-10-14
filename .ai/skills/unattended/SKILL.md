---
name: unattended
description: Continue the current task without user input while the user is away. Use only when invoked directly.
disable-model-invocation: true
---

# Unattended mode

Work independently until the task is complete or no useful work remains.

- Do not wait for user input. Make conservative, reversible decisions and continue.
- Unblock yourself by trying reasonable alternatives, fixing failures, and skipping optional blocked steps.
- Keep implementing, testing, and documenting even if a commit, push, credential, approval, or external service is unavailable.
- If commit signing is blocked, leave the changes uncommitted. Never disable or bypass signing.
- Do not perform destructive, irreversible, security-sensitive, or externally visible actions without prior authorization.
- Record blockers, assumptions, skipped steps, and unfinished work in the final response.
- Do not claim completion when required work remains blocked.
