#!/bin/bash

set -e

# -------------------------------------
# Cron Jobs

install_cron() {
  local name="$1"
  local entry="$2"
  local log_dir="$HOME/.local/log"

  mkdir -p "$log_dir"

  if crontab -l 2>/dev/null | grep -qF "$name"; then
    echo "cron: $name already installed, skipping"
  else
    (crontab -l 2>/dev/null || true; echo "$entry") | crontab -
    echo "cron: installed $name"
  fi
}

# Scan shell history for secrets daily at 9am.
# Logs to ~/.local/log/purge-history-secrets.log
install_cron \
  "purge-history-secrets" \
  "0 9 * * * $HOME/.dotfiles/bin/purge-history-secrets"
