#!/bin/bash

set -e

# -------------------------------------
# Cron Jobs

install_cron() {
  local name="$1"
  local entry="$2"

  mkdir -p "$HOME/.local/dotlogs"

  local current
  current="$(crontab -l 2>/dev/null || true)"

  if printf '%s\n' "$current" | grep -qxF "$entry"; then
    echo "cron: $name up to date"
    return
  fi

  # Replace, not skip: a name match with a different command is a stale entry
  # (old ~/.dotfiles path, missing PATH prefix) that must converge on every
  # machine.
  {
    printf '%s\n' "$current" | grep -vF "$name" | grep -v '^[[:space:]]*$' || true
    echo "$entry"
  } | crontab -
  echo "cron: installed $name"
}

# Scan shell history for secrets daily at 9am. cron provides no useful PATH,
# so the entry carries its own: the job needs uv (mise shims) and trufflehog
# (Homebrew). Values are baked in at install time — cron inherits nothing
# from any shell.
# The script writes its own log to ~/.local/dotlogs/purge-history-secrets.log
install_cron \
  "purge-history-secrets" \
  "0 9 * * * PATH=/opt/homebrew/bin:$HOME/.local/share/mise/shims:/usr/bin:/bin ${DOTFILES_DIR:-$HOME/.dotfiles}/bin/purge-history-secrets"
