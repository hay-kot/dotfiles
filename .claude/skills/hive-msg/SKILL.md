---
name: hive-msg
description: Publish and subscribe to inter-agent messages using hive msg for coordination between sessions.
argument-hint: [pub|sub|list] [topic] [message]
disable-model-invocation: true
---

# Hive Messaging - Inter-Agent Communication

Use `hive msg` for topic-based pub/sub messaging between agents. Messages are stored in topic-based JSON files and persist across sessions.

## Default Topic

**Unless a specific topic is needed, use `agent` as the default topic.**

```bash
# Default communication
hive msg pub -t agent "status update or message"
hive msg sub -t agent
```

## Commands

```bash
# Publish a message
hive msg pub -t <topic> "message"
hive msg pub -t <topic> -f file.txt
echo "message" | hive msg pub -t <topic>

# Subscribe/read messages
hive msg sub                          # all messages
hive msg sub -t <topic>               # specific topic
hive msg sub -t "prefix.*"            # wildcard pattern
hive msg sub -n 10                    # last 10 messages
hive msg sub -l                       # poll for new messages
hive msg sub -l --timeout 5m          # poll with timeout

# List topics
hive msg list
```

## Topic Naming Conventions

Use dot-separated hierarchical topics when you need specificity:

```bash
# General inter-agent (default)
hive msg pub -t agent "starting phase 2"

# Specific coordination
hive msg pub -t agent.handoff "completed API layer"
hive msg pub -t agent.status "working on auth module"

# Build/test events
hive msg pub -t build.started "building main branch"
hive msg pub -t build.completed "success"
hive msg pub -t test.failed "3 tests failed in auth module"

# Research findings
hive msg pub -t research.finding "auth handler at src/auth/handler.go:45"

# Cross-repo coordination
hive msg pub -t repo.backend.api-changed "new required field: role"
```

## When to Use Messaging

**Good use cases:**
- Coordinating parallel agent sessions
- Broadcasting status updates
- Passing discoveries between agents
- Event-driven workflows
- Cross-session notifications

**Use files in `.hive/` instead for:**
- Large documents (plans, research notes)
- Data that needs structured formatting
- Content that should be version controlled

## Examples

### Simple agent communication

```bash
# Send a message
hive msg pub -t agent "completed database migrations"

# Check for messages
hive msg sub -t agent -n 5
```

### Coordinate parallel research

Agent 1:
```bash
hive msg pub -t research.cache "Redis approach: see .hive/research/redis-poc.md"
```

Agent 2:
```bash
hive msg sub -t "research.*"
```

### Handoff between sessions

Finishing agent:
```bash
hive msg pub -t agent "API complete. Frontend needs: UserForm component for new role field"
```

New agent:
```bash
hive msg sub -t agent -n 5
```

### Watch for build completion

```bash
# In one session, run build and notify
make build && hive msg pub -t build.done "success" || hive msg pub -t build.done "failed"

# In another session, wait for it
hive msg sub -t build.done -l --timeout 10m
```

## Message Format

Messages include metadata automatically:
- Timestamp
- Sender (auto-detected from hive session)
- Topic

Output from `hive msg sub` is JSON, making it easy to parse programmatically.

## Integration with Hive Batch

Combine with `hive batch` for coordinated parallel work:

1. Spawn parallel agents with `hive batch`
2. Agents publish findings to shared topics
3. Coordinator subscribes to aggregate results

```bash
# Spawn research agents
echo '{"sessions":[
  {"name":"redis-research","prompt":"Research Redis caching, publish findings to agent topic when done"},
  {"name":"memcached-research","prompt":"Research Memcached, publish findings to agent topic when done"}
]}' | hive batch

# Later, collect results
hive msg sub -t agent
```
