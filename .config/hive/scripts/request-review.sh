#!/bin/bash
# Usage: request-review.sh <session-name> <agent-send> <agent-window>
# Requests a code review of the current branch

CURRENT_SESSION_NAME="${1:-}"
AGENT_SEND="${2:-agent-send}"
AGENT_WINDOW="${3:-claude}"

if [ -z "$CURRENT_SESSION_NAME" ]; then
    echo "Error: Session name required"
    exit 1
fi

CURRENT_SESSION=$(hive session info --json)
CURRENT_REPO=$(echo "$CURRENT_SESSION" | jq -r '.remote')
CURRENT_BRANCH=$(git branch --show-current)

if [ -z "$CURRENT_BRANCH" ]; then
    echo "Error: Not on a git branch"
    exit 1
fi

# hive rejects session names over 60 characters; "review-" and "-<id>" take 12.
SAFE_BRANCH=$(echo "$CURRENT_BRANCH" | tr '/' '-' | cut -c1-48)

NEW_SESSION=$(hive msg topic --prefix "")
REVIEWER_INBOX="agent.$NEW_SESSION.inbox"

BATCH_JSON=$(cat <<EOF
{
  "sessions": [
    {
      "session_id": "$NEW_SESSION",
      "name": "review-$SAFE_BRANCH-$NEW_SESSION",
      "remote": "$CURRENT_REPO",
      "prompt": "You are a code reviewer. Review instructions arrive in your inbox ($REVIEWER_INBOX). Read them with: hive msg inbox --ack. If the inbox is empty, wait for the first message with: hive msg inbox --wait --ack --timeout 30m"
    }
  ]
}
EOF
)

echo "$BATCH_JSON" | hive batch

"$AGENT_SEND" "$CURRENT_SESSION_NAME:$AGENT_WINDOW" "A reviewer is waiting for a message from you at $REVIEWER_INBOX. Send them context on the work you are doing, how to access your branch, and what to review, with: hive msg pub -t $REVIEWER_INBOX -m '<message>'. Then wait up to 1 hour for their response with: hive msg inbox --wait --ack --timeout 1h"
