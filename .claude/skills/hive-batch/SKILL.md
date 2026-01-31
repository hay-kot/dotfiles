---
name: hive-batch
description: Spawn multiple parallel AI agent sessions using hive batch for completely independent work streams.
argument-hint: [task-description]
disable-model-invocation: true
---

# Hive Batch - Parallel Agent Sessions

Use `hive batch` to spawn multiple isolated agent sessions. Each session gets its own git worktree and runs independently.

## When to Use

**Good use cases:**
- Research multiple approaches to a problem in parallel
- Fix several unrelated GitHub issues simultaneously
- Explore different implementation ideas independently
- Batch process unrelated tasks across repos

**Do NOT use for:**
- Work that belongs in the same branch
- Tasks with dependencies on each other
- Sequential work where one task informs the next

## JSON Schema

```json
{
  "sessions": [
    {"name": "session-name", "prompt": "task description"},
    {"name": "another-session", "prompt": "another task"}
  ]
}
```

Fields:
- `name` (required): Short identifier for the session (used in tab title)
- `prompt` (optional): The prompt passed to claude in the spawned terminal
- `remote` (optional): Git remote URL if different from current repo
- `source` (optional): Directory to copy files from (per copy rules in config)

## Critical: Avoid Double Quotes in Prompts

The spawn command passes prompts through shell escaping. **Never use `"` in prompt text** as it breaks escaping. Use single quotes instead.

Bad:
```json
{"name": "fix", "prompt": "Fix the \"broken\" function"}
```

Good:
```json
{"name": "fix", "prompt": "Fix the 'broken' function"}
```

## Usage

Pipe JSON directly:
```bash
echo '{"sessions":[{"name":"task1","prompt":"implement feature X"}]}' | hive batch
```

Or use a file:
```bash
hive batch -f sessions.json
```

## Example: Researching Ideas

```bash
echo '{"sessions":[
  {"name":"approach-a","prompt":"Research using Redis for caching - create a proof of concept"},
  {"name":"approach-b","prompt":"Research using in-memory LRU cache - create a proof of concept"}
]}' | hive batch
```

## Example: Fixing Unrelated Issues

```bash
echo '{"sessions":[
  {"name":"issue-123","prompt":"Fix GitHub issue #123 - login button not responding"},
  {"name":"issue-456","prompt":"Fix GitHub issue #456 - incorrect date formatting"}
]}' | hive batch
```

## Guidelines

1. Keep session names short (they appear in terminal tabs)
2. Make prompts self-contained - each agent works in complete isolation
3. Only use for truly independent work streams
4. Use single quotes in prompts, never double quotes
