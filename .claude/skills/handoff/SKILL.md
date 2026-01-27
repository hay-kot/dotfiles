---
name: handoff
description: Handoff work to a new agent in a different repository with context
argument-hint: <repo-name> <handoff-message>
---

# Handoff - Cross-Repository Agent Coordination

Spawn a new Claude Code agent in a different repository with a handoff document containing context from the current work.

## Usage

```
/handoff <repo-name> <handoff-message>
```

Where:
- `<repo-name>`: Name of the target repository (must exist in `/Users/hayden/Code/repos/`)
- `<handoff-message>`: Context and instructions for the new agent

## What This Does

1. Resolves the full path to the target repo
2. Gets the git remote URL from the target repo
3. Creates a handoff document with:
   - Source repository context
   - The handoff message
   - Any relevant files or data
4. Spawns a new agent in the target repo using `hive batch`
5. Passes the handoff document to the new agent

## Example: Metrics to Dashboard

From a service repository:
```
/handoff deployment_tools Please create a dashboard for the newly added metrics: request_duration_seconds, request_total, error_rate. These metrics were added in commit abc123 and are exposed at /metrics endpoint. The dashboard should include 95th percentile latency and error rates over time.
```

## Example: API Changes

From a backend repository:
```
/handoff frontend-app The user API endpoint /api/v1/users now requires an additional 'role' field in the request body. Please update the frontend forms and TypeScript types to include this field. See backend/api/users.go:45 for the new schema.
```

## Example: Full Handoff Document Structure

A well-structured handoff document should include:

```markdown
# Handoff from backend-service

## Context
- Source repo: backend-service (github.com/org/backend-service)
- Changes made in commit: abc123
- Related PR: #456

## Task
Create a Grafana dashboard for newly added Prometheus metrics.

## Metrics Added
The following metrics are now exposed at `/metrics`:
- `http_request_duration_seconds` - histogram of request latencies
- `http_request_total` - counter of total requests
- `http_error_total` - counter of errors by status code

## Implementation Details
See `internal/metrics/http.go:45-78` for metric definitions.

The metrics include labels:
- `method` (GET, POST, etc.)
- `path` (API endpoint)
- `status` (HTTP status code)

## Dashboard Requirements
- Panel for 95th percentile latency over time
- Panel for request rate (requests/sec)
- Panel for error rate by status code
- Time range: last 24 hours default
```

## Implementation Steps

When this skill is invoked, execute the following:

1. **Parse arguments**: Extract `<repo-name>` and `<handoff-message>` from the skill invocation

2. **Validate target repository**:
   ```bash
   ls /Users/hayden/Code/repos/<repo-name>
   ```

3. **Get the git remote URL**:
   ```bash
   git -C /Users/hayden/Code/repos/<repo-name> remote get-url origin
   ```

4. **Get current repository info**:
   ```bash
   git remote get-url origin
   pwd
   ```

5. **Build handoff document**: Create a comprehensive prompt that includes:
   - Source repo: `<current-repo-name>`
   - Target repo: `<repo-name>`
   - Context: `<handoff-message>`
   - Any relevant file paths, commit SHAs, or code snippets

6. **Write to temporary file** (recommended for all handoffs):
   ```bash
   cat > /tmp/handoff_payload.json << 'EOF'
   {"sessions":[{"name":"handoff-from-<source>","remote":"<target-remote-url>","prompt":"<handoff-document>"}]}
   EOF
   ```

7. **Execute hive batch**:
   ```bash
   cat /tmp/handoff_payload.json | hive batch
   ```

**Always use file-based approach**: Writing to a temp file first avoids all shell escaping issues with quotes, backticks, code blocks, and markdown formatting.

## Understanding the Output

**Success indicators:**
- Look for: `session created: <session-id>`
- This confirms the agent was spawned successfully

**Ignore shell parsing errors:**
- You may see errors like `sh: POST: command not found` or similar
- These are just parsing noise from the output
- The agent receives the correct prompt despite these errors
- Focus on the "session created" line

**Verify handoff:**
```bash
# Check the spawned session (if you want to verify)
hive ls
# The new session should appear in the list
```

## Guidelines

1. **Always use the file-based approach** - Write payload to `/tmp/handoff_payload.json` first
2. **Keep handoff messages focused and actionable** - The new agent needs clear instructions
3. **Include specific file paths, commit SHAs, or line numbers** when relevant
4. **Be explicit** - The new agent has no access to this conversation
5. **Include code examples freely** - The file-based approach handles markdown, backticks, and quotes correctly
6. **Structure complex handoffs** - Use markdown headers to organize: Context, Task, References

## Anti-Patterns

**Don't use for:**
- Work in the same repository (use regular Task tool instead)
- Sequential dependent work (finish current work first, then handoff)
- When you need bidirectional communication (handoff is one-way)

**Do use for:**
- Cross-repository coordination
- Parallel work streams in different repos
- Delegating follow-up work to another codebase
- Creating artifacts based on work done in current repo
