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

  # replace, not skip: a name match with a different command is a stale entry
  {
    printf '%s\n' "$current" | grep -vF "$name" | grep -v '^[[:space:]]*$' || true
    echo "$entry"
  } | crontab -
  echo "cron: installed $name"
}

# Scan shell history for secrets daily at 9am. The entry carries its own PATH:
# cron provides none, and the job needs uv (mise shims) and trufflehog (brew).
install_cron \
  "purge-history-secrets" \
  "0 9 * * * PATH=/opt/homebrew/bin:$HOME/.local/share/mise/shims:/usr/bin:/bin ${DOTFILES_DIR:-$HOME/.dotfiles}/bin/purge-history-secrets"
