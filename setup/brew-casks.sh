#!/usr/bin/env bash
set -euo pipefail

# Casks mise can't install — Homebrew stays solely for these. The list comes
# from BREW_ESCAPE_CASKS, set per machine in the mise overlay [env] sections.

if [ -z "${BREW_ESCAPE_CASKS:-}" ]; then
  echo "brew-casks: BREW_ESCAPE_CASKS is empty; nothing to do"
  exit 0
fi

command -v brew >/dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# absolute path: a just-installed Homebrew isn't on this process's PATH yet
brew=/opt/homebrew/bin/brew
for cask in $BREW_ESCAPE_CASKS; do
  "$brew" list --cask "$cask" >/dev/null 2>&1 || "$brew" install --cask "$cask"
done
