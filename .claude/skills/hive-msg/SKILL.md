---
name: hive-msg
description: Start or connect to inter-agent messaging topics for real-time collaboration between Claude sessions.
argument-hint: start <context> | connect
---

# Hive Messaging - Real-Time Agent Collaboration

This skill enables real-time communication between Claude agents across different sessions. Agents connect to a shared topic and use blocking waits to synchronize their work.

## Quick Reference

| Command | Purpose |
|---------|---------|
| `/hive-msg start <context>` | Create a topic and send initial message |
| `/hive-msg connect` | Join the most recent topic |

## How It Works

1. **Initiator** runs `/hive-msg start` → creates topic, announces it, sends first message, waits for response
2. **Responder** runs `/hive-msg connect` → finds topic, joins, acknowledges, waits for messages
3. **Both agents** exchange messages using `--wait` to block until the other responds
4. **Conversation ends** naturally when the task is complete

---

## Starting a Topic

When the user asks you to start a messaging topic:

### Step 1: Generate Topic ID

Generate a random 4-character alphanumeric ID:

```bash
# Generate random topic ID
TOPIC_ID=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 4)
echo "agent.$TOPIC_ID"
```

### Step 2: Announce to Topics Channel

Publish an announcement so other agents can discover this topic:

```bash
hive msg pub -t topics "$(cat <<'EOF'
## agent.<TOPIC_ID>
repo: <current-repo-name>
branch: <current-branch>
purpose: <brief description of what you need>
EOF
)"
```

### Step 3: Send Initial Message

Send the actual request/context to the topic:

```bash
hive msg pub -t agent.<TOPIC_ID> "$(cat <<'EOF'
# Request from <repo-name>

<The user's context/request in markdown format>

## Context
- Repo: <repo-name>
- Branch: <branch>
- Relevant files: <list key files if applicable>

Please respond when you've reviewed this.
EOF
)"
```

### Step 4: Optionally Track State

If `.hive/` exists, save current topic for reference:

```bash
mkdir -p .hive
echo '{"topic": "agent.<TOPIC_ID>", "role": "initiator", "started": "<timestamp>"}' > .hive/topics.json
```

### Step 5: Enter Wait Mode

Wait for a response from the other agent:

```bash
# If you have no other work, block and wait:
hive msg sub -w -t agent.<TOPIC_ID> --timeout 30m

# If you have other work, run in background and check later
```

When using `run_in_background: true` with the Bash tool, periodically check for responses using TaskOutput.

**Tell the user:** "Topic `agent.<TOPIC_ID>` created. Waiting for another agent to connect. They should run `/hive-msg connect` to join."

---

## Connecting to a Topic

When the user asks you to connect to a messaging topic:

### Step 1: Find Latest Topic

Read the most recent announcement from the topics channel:

```bash
hive msg sub -t topics -n 1
```

Parse the topic name (e.g., `agent.x7k2`) from the announcement.

### Step 2: Read Existing Messages

Check for any messages already on the topic:

```bash
hive msg sub -t agent.<TOPIC_ID> -n 5
```

### Step 3: Send Acknowledgment

Let the initiator know you've connected:

```bash
hive msg pub -t agent.<TOPIC_ID> "$(cat <<'EOF'
# Connected from <repo-name>

I've joined the topic and reviewed your request.

<Brief acknowledgment of what you understood>

Working on this now.
EOF
)"
```

### Step 4: Optionally Track State

```bash
mkdir -p .hive
echo '{"topic": "agent.<TOPIC_ID>", "role": "responder", "joined": "<timestamp>"}' > .hive/topics.json
```

### Step 5: Enter Wait Mode or Do Work

If the request requires investigation/work, do that work first. Then respond with findings and enter wait mode for follow-up:

```bash
# After completing work, send response:
hive msg pub -t agent.<TOPIC_ID> "<your findings/response>"

# Then wait for follow-up:
hive msg sub -w -t agent.<TOPIC_ID> --timeout 30m
```

**Tell the user:** "Connected to topic `agent.<TOPIC_ID>`. Reviewed the request from <initiator-repo>."

---

## While Connected (Modal Behavior)

Once connected to a topic, you are in **messaging mode**. Continue this pattern:

### Sending Messages

```bash
hive msg pub -t agent.<TOPIC_ID> "$(cat <<'EOF'
<Your message in markdown>
EOF
)"
```

### Waiting for Responses

```bash
# Blocking wait (use when you have nothing else to do)
hive msg sub -w -t agent.<TOPIC_ID> --timeout 30m

# Background wait (use when you have other work)
# Run with run_in_background: true, then check with TaskOutput
```

### Timeout Handling

If `--wait` times out after 30 minutes:
- Inform the user: "No response received in 30 minutes."
- Ask user how to proceed: wait longer, send a follow-up, or end the conversation

### Ending the Conversation

The messaging session ends naturally when:
- The task is complete and both agents confirm
- The user indicates they're done
- The conversation ends

No explicit disconnect is needed - topics persist for potential future reference.

---

## Message Format Guidelines

Messages should be **markdown formatted** for readability:

```markdown
# <Brief Title>

<Main content>

## Findings / Response / Request
- Point 1
- Point 2

## Questions (if any)
- Question 1?
```

Include relevant context (repo, branch, file paths) when it helps the other agent understand.

---

## Example Flow

### Agent 1 (dotfiles repo)

```
User: /hive-msg start ask the grafana agent to review our k8s config changes

Agent 1:
1. Generates topic: agent.m4x9
2. Announces to topics channel
3. Sends: "Please review k8s config changes in dotfiles repo..."
4. Waits for response
```

### Agent 2 (grafana repo)

```
User: /hive-msg connect

Agent 2:
1. Reads topics channel, finds agent.m4x9
2. Reads initial message about k8s config review
3. Sends: "Connected. Reviewing the config changes now..."
4. Does the review work
5. Sends: "Review complete. Found 2 issues: ..."
6. Waits for follow-up
```

### Agent 1 receives response

```
Agent 1:
1. Receives review findings
2. Shows user the feedback
3. Sends: "Thanks, fixing those issues now..."
4. Makes fixes
5. Sends: "Fixed. Can you verify?"
6. Waits for confirmation
```

---

## CLI Reference

```bash
# Publish a message
hive msg pub -t <topic> "message"
hive msg pub -t <topic> -f file.txt

# Read messages
hive msg sub -t <topic>           # all messages on topic
hive msg sub -t <topic> -n 5      # last 5 messages

# Wait for next message (blocking)
hive msg sub -w -t <topic> --timeout 30m

# List all topics
hive msg list

# Read from topics channel
hive msg sub -t topics -n 1
```
