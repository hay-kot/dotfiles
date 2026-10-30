---
name: enable-push
description: Send the user push notifications through ntfy for the rest of the session when work finishes, needs them, or reaches a milestone worth knowing about. Use only when invoked directly.
argument-hint: "[when to notify]"
disable-model-invocation: true
allowed-tools: "Bash(~/.claude/skills/enable-push/scripts/push.sh:*)"
---

# Push notifications

The user is away from the terminal. For the rest of this session, send a push
notification when one of the statuses below applies, until the user says to stop.

Confirm in one line that push notifications are on, then continue any pending work.

## Send

```bash
~/.claude/skills/enable-push/scripts/push.sh [-a <image>] <status> "<signature>" "<message>"
```

The script titles the notification `<repo>: <Status>`, sets the priority from the
status, and signs the message on its last line as `- <signature>`. It finds the
ntfy URL and token on its own. Never look for, read, or print them, and never
send notifications any other way.

If the script fails, say so in your next response and keep working. Do not retry
in a loop.

## Statuses

Instructions passed with the invocation replace the "When" column. Pick the
closest status for each send.

| Status    | When                                                                          | Priority |
| --------- | ----------------------------------------------------------------------------- | -------- |
| `done`    | The requested work is complete and you are about to end your turn.            | default  |
| `blocked` | You need a decision, approval, credential, or answer before you can continue. | high     |
| `failed`  | An error stops the work and you have run out of reasonable fixes.             | high     |
| `update`  | Something the user would want to know before the work ends. See below.        | low      |

Send `done`, `blocked`, and `failed` as the last action before you stop, after the
final summary is ready. Send at most one of them per stop.

### Updates

An update must change what the user knows or might do. Good reasons:

- A milestone the user is waiting on: a PR opened, CI went green, or a long run
  finished one of several phases.
- A finding that changes the plan or the scope.
- A decision you made on an assumption the user may want to reverse.
- A UI change that reached a state worth a look: a new screen or component
  renders for the first time, or a visual choice the user may want to redirect
  early. Attach a screenshot. Send one per visual state worth reviewing, not one
  per tweak.

Never send an update to report progress, a finished step, or a subagent result.
If you are unsure whether an update is worth sending, do not send it.

## Images

Images show inline on the user's phone, and a screenshot often says more about
visual work than a sentence can. Attach one with `-a <image>` to any notification
about something visible, such as a UI change. Never attach an image that shows
secrets, credentials, or private data. The file leaves this machine.

## Signature

The signature tells the user which piece of work sent the notification. Other
agents often work in the same repository at the same time, so the signature must
name this session's specific task, not the repository or a generic category like
`Bug Fix` or `Refactor`. Use two to four Title Case words, such as
`Recipe Import Rewrite` or `Load Testing Agent`. Pick it on the first send and
reuse it unchanged for the rest of the session.

## Message

- One or two plain sentences: what happened and what you need from the user, if anything.
- Do not repeat the signature or the status in the message.
- Plain text only. The user's phone does not render markdown.
- Leave out secrets, credentials, and code or log excerpts. The message leaves this machine.
