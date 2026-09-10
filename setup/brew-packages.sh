#!/usr/bin/env bash
set -euo pipefail

# Packages mise cannot fetch directly use the Homebrew CLI. Formula taps must
# publish API metadata for mise; some third-party taps do not. Some casks have
# installer steps that mise does not support.

if [ -z "${BREW_ESCAPE_FORMULAS:-}" ] && [ -z "${BREW_ESCAPE_CASKS:-}" ]; then
  echo "brew-packages: no escape packages configured; nothing to do"
  exit 0
fi

command -v brew >/dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# absolute path: a just-installed Homebrew isn't on this process's PATH yet
brew=/opt/homebrew/bin/brew
for formula in ${BREW_ESCAPE_FORMULAS:-}; do
  "$brew" list --formula "$formula" >/dev/null 2>&1 || "$brew" install "$formula"
done
for cask in ${BREW_ESCAPE_CASKS:-}; do
  "$brew" list --cask "$cask" >/dev/null 2>&1 || "$brew" install --cask "$cask"
done
