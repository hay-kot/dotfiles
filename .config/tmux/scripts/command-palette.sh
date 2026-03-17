#!/usr/bin/env sh

COMMANDS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/scripts/commands.txt"

if [ ! -f "$COMMANDS_FILE" ]; then
    echo "No commands file found: $COMMANDS_FILE"
    exit 1
fi

# Format: Name|Description|Command
# Show "Name  Description" in fzf, extract command from matching line
selection=$(grep -v '^#' "$COMMANDS_FILE" | grep -v '^$' |
    awk -F'|' '{printf "%s\t\033[90m%s\033[0m\n", $1, $2}' |
    fzf --ansi --reverse --no-info --with-nth 1.. |
    cut -f1)

if [ -n "$selection" ]; then
    cmd=$(grep "^${selection}|" "$COMMANDS_FILE" | head -1 | cut -d'|' -f3-)
    tmpfile=$(mktemp /tmp/tmux-palette.XXXXXX)
    echo "$cmd" > "$tmpfile"
    tmux run-shell -b "sleep 0.3; sh '$tmpfile'; rm -f '$tmpfile'"
fi
