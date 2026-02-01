---
name: hive-handoff
description: Handoff work to a new agent in a different repository with context and messaging channel
argument-hint: <repo-name> <handoff-message>
---

# Hive Handoff

Spawn an agent in another repo with context and a reply channel.

## Usage

```
/hive-handoff <repo-name> <handoff-message>
```

## Steps

1. Get your session ID: `hive session info`
2. Validate target: `ls /Users/hayden/Code/repos/<repo-name>`
3. Get remote: `git -C /Users/hayden/Code/repos/<repo-name> remote get-url origin`
4. Build handoff with your inbox for replies
5. Write to `/tmp/handoff_payload.json`
6. Execute: `cat /tmp/handoff_payload.json | hive batch`

## Handoff Template

```markdown
# Handoff from <source-repo>

## Task
<handoff-message>

## Reply Channel
agent.<your-session-id>.inbox
```

## Receiving Updates

```bash
hive msg sub -t agent.{your-id}.inbox --new
```

If stuck on messaging, run `hive doc messaging`.
