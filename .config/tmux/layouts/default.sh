#!/bin/bash
# Default layout - single session
# Usage: default.sh [session-name]

SESSION="${1:-main}"

if tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux attach-session -t "$SESSION"
else
    tmux new-session -s "$SESSION"
fi
