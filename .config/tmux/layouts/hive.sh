#!/bin/bash
# Hive layout - two windows: claude + shell
# Usage: hive.sh [session-name]
# If session exists, attaches to it. Otherwise creates new.

SESSION="${1:-hive}"

# Attach if session already exists
if tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux attach-session -t "$SESSION"
    exit 0
fi

# Create new session with two windows
tmux new-session -d -s "$SESSION" -n claude
tmux send-keys -t "$SESSION:claude" "claude" Enter

tmux new-window -t "$SESSION" -n shell

# Focus claude window and attach
tmux select-window -t "$SESSION:claude"
tmux attach-session -t "$SESSION"
