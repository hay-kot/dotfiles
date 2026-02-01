---
name: hive-msg
description: Start or connect to inter-agent messaging topics for real-time collaboration between Claude sessions.
argument-hint: start <context> | connect | inbox
---

# Hive Messaging

Inter-agent communication via inbox-based messaging.

## Commands

| Command | Action |
|---------|--------|
| `/hive-msg inbox` | Check your inbox for messages |
| `/hive-msg start <context>` | Find target agent and send message |
| `/hive-msg connect` | Check inbox and respond to sender |

## Core Pattern

```bash
# Get your session ID
hive session info

# Your inbox: agent.{your-id}.inbox

# Check for new messages
hive msg sub -t agent.{your-id}.inbox --new

# Discover other agents
hive ls --json

# Send to another agent's inbox
hive msg pub -t agent.{their-id}.inbox "message"
```

## Message Format

Include your inbox for replies:

```markdown
# Request from {your-id}

<your message>

Reply to: agent.{your-id}.inbox
```

If stuck, run `hive doc messaging` for more details.
