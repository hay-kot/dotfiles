#!/bin/bash
# Hive layout - two windows: claude + shell
# Usage: hive.sh [session-name] [working-dir] [prompt]
# If session exists, switches/attaches. Otherwise creates new.
# Works both inside and outside tmux.

SESSION="${1:-hive}"
WORKDIR="${2:-$PWD}"
PROMPT="${3:-}"

if tmux has-session -t "$SESSION" 2>/dev/null; then
    # Session exists - switch or attach
    if [ -n "$TMUX" ]; then
        tmux switch-client -t "$SESSION"
    else
        tmux attach-session -t "$SESSION"
    fi
else
    # Create new session with two windows
    tmux new-session -d -s "$SESSION" -n claude -c "$WORKDIR"

    # Start claude with or without prompt
    if [ -n "$PROMPT" ]; then
        tmux send-keys -t "$SESSION:claude" "claude '$PROMPT'" Enter
    else
        tmux send-keys -t "$SESSION:claude" "claude" Enter
    fi

    tmux new-window -t "$SESSION" -n shell -c "$WORKDIR"
    tmux select-window -t "$SESSION:claude"

    # Switch or attach
    if [ -n "$TMUX" ]; then
        tmux switch-client -t "$SESSION"
    else
        tmux attach-session -t "$SESSION"
    fi
fi
