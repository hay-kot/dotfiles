#!/bin/bash
# Hive layout - two windows: claude + shell
# Usage: hive.sh [-b] [session-name] [working-dir] [prompt]
#   -b: background mode (create session without attaching)
# If session exists, switches/attaches. Otherwise creates new.
# Works both inside and outside tmux.

BACKGROUND=false
if [ "$1" = "-b" ]; then
    BACKGROUND=true
    shift
fi

SESSION="${1:-hive}"
WORKDIR="${2:-$PWD}"
PROMPT="${3:-}"

# Build claude command
if [ -n "$PROMPT" ]; then
    CLAUDE_CMD="claude '$PROMPT'"
else
    CLAUDE_CMD="claude"
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
    # Session exists
    if [ "$BACKGROUND" = true ]; then
        exit 0
    fi
    if [ -n "$TMUX" ]; then
        tmux switch-client -t "$SESSION"
    else
        tmux attach-session -t "$SESSION"
    fi
else
    # Create new session running claude directly
    tmux new-session -d -s "$SESSION" -n claude -c "$WORKDIR" "$CLAUDE_CMD"
    tmux new-window -t "$SESSION" -n shell -c "$WORKDIR"
    tmux select-window -t "$SESSION:claude"

    if [ "$BACKGROUND" = true ]; then
        exit 0
    fi

    if [ -n "$TMUX" ]; then
        tmux switch-client -t "$SESSION"
    else
        tmux attach-session -t "$SESSION"
    fi
fi
