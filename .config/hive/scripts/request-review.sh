#!/bin/bash
# Usage: request-review.sh
# Requests a code review of the current branch

# Get current session info
CURRENT_SESSION=$(hive session info --json)
CURRENT_REPO=$(echo "$CURRENT_SESSION" | jq -r '.remote')
CURRENT_BRANCH=$(git branch --show-current)
CURRENT_SESSION_NAME="${1:-}"

if [ -z "$CURRENT_BRANCH" ]; then
    echo "Error: Not on a git branch"
    exit 1
fi

# Sanitize branch name for use in session name (replace / with -)
SAFE_BRANCH=$(echo "$CURRENT_BRANCH" | tr '/' '-')

NEW_SESSION=$(hive msg topic --prefix "")

# Create new review session with instructions
BATCH_JSON=$(cat <<EOF
{
  "sessions": [
    {
      "session_id": "$NEW_SESSION",
      "name": "review-$SAFE_BRANCH-$NEW_SESSION",
      "origin": "$CURRENT_REPO",
      "prompt": "You are a code reviewer. Check your inbox (agent.$NEW_SESSION.inbox) for review instructions using: hive msg sub -t agent.{session-id}.inbox --new, wait until you recieve a message. If no messages are available use hive msg sub --topic=<topic> --wait to wait for a message"
    }
  ]
}
EOF
)

echo "$BATCH_JSON" | hive batch

# Send review context to new session's inbox
#
claude-send "$CURRENT_SESSION_NAME:claude" "/hive-msg a reviwer is wating for a message from you at agent.$NEW_SESSION.inbox. Please send them context on the work you are doing and how they can access your branch and review the code. Wait up to 1 hour for a response"
