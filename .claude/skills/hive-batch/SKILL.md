---
name: hive-batch
description: Spawn multiple parallel AI agent sessions using hive batch for completely independent work streams.
argument-hint: [task-description]
disable-model-invocation: true
---

# Hive Batch - Parallel Agent Sessions

Spawn isolated agent sessions with their own git worktrees.

## JSON Schema

```json
{
  "sessions": [
    {"name": "session-name", "prompt": "task description"}
  ]
}
```

Fields: `name` (required), `prompt`, `remote`, `source`

## Usage

```bash
echo '{"sessions":[{"name":"task1","prompt":"implement feature X"}]}' | hive batch
```

## Agent Coordination

Spawned agents can message each other via inboxes:

```bash
hive session info                           # Get your ID
hive ls --json                              # Find other agents
hive msg pub -t agent.{id}.inbox "message"  # Send
hive msg sub -t agent.{id}.inbox --new      # Receive
```

## Guidelines

- Keep session names short
- Use single quotes in prompts, never double quotes
- Only for truly independent work streams

If stuck on messaging, run `hive doc messaging`.
