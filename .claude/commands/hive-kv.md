---
allowed-tools: Bash(hive ctx kv:*)
description: Key-value store for inter-agent communication and session state
---

# Hive KV Store

The `hive ctx kv` command provides a key-value store for persisting state across sessions and enabling inter-agent communication.

## Commands

```bash
# Set a value
hive ctx kv set <key> <value>
echo "multiline value" | hive ctx kv set <key>

# Get a value
hive ctx kv get <key>

# List keys (optionally filter by prefix)
hive ctx kv list [prefix]
hive ctx kv list --json

# Delete a key
hive ctx kv delete <key>

# Watch for changes (useful for reactive workflows)
hive ctx kv watch <key>
```

## Flags

- `--repo owner/repo` - Target a specific repository's context
- `--shared` - Use the shared context directory (cross-repo state)

## Key Naming Conventions

Use namespaced, dot-separated keys for organization:

```bash
# Plan execution state
hive ctx kv set plan.current_phase "Phase 2"
hive ctx kv set plan.status "in_progress"
hive ctx kv set plan.last_completed "2025-01-28-auth-feature"

# Research state
hive ctx kv set research.current_topic "authentication-flow"
hive ctx kv set research.last_query "how does session management work"

# Agent coordination
hive ctx kv set agent.task_id "abc123"
hive ctx kv set agent.handoff_note "completed API, needs frontend"

# User preferences (shared across repos)
hive ctx kv set --shared prefs.editor "zed"
hive ctx kv set --shared prefs.test_runner "make test"
```

## When to Use KV

**Good use cases:**
- Tracking progress across session restarts
- Storing decisions made during planning
- Passing context between agents
- Remembering user preferences
- Caching expensive lookups

**Avoid using for:**
- Large data (use files in `.hive/` instead)
- Sensitive information
- Data that should be version controlled

## Examples

### Track plan execution progress

```bash
# Before starting a phase
hive ctx kv set plan.current_phase "Phase 1: Database Schema"
hive ctx kv set plan.status "in_progress"

# After completing
hive ctx kv set plan.status "completed"
hive ctx kv set plan.last_completed "Phase 1: Database Schema"
```

### Store research findings for later

```bash
# Save key discovery
hive ctx kv set research.auth_handler "src/auth/handler.go:45"
hive ctx kv set research.session_store "pkg/session/redis.go:123"
```

### Check existing state

```bash
# See all plan-related keys
hive ctx kv list plan.

# Get current status
hive ctx kv get plan.status
```

## Integration with Other Skills

The KV store complements file-based storage in `.hive/`:
- **Files** (`.hive/plans/`, `.hive/research/`): Detailed documents, plans, research
- **KV**: Quick state, progress tracking, cross-agent coordination

Use KV for metadata about files:
```bash
hive ctx kv set plan.active ".hive/plans/2025-01-28-auth-feature.md"
hive ctx kv set plan.phase_count "4"
```
