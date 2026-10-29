#!/usr/bin/env bash
set -euo pipefail

# Formulae mise cannot fetch use the Homebrew CLI. mise reads taps through the
# GitHub API, which cannot see a private tap without an SSO-authorized token.

if [ -z "${BREW_ESCAPE_FORMULAS:-}" ]; then
  echo "brew-packages: no escape formulae configured; nothing to do"
  exit 0
fi

command -v brew >/dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# absolute path: a just-installed Homebrew isn't on this process's PATH yet
brew=/opt/homebrew/bin/brew
for formula in ${BREW_ESCAPE_FORMULAS:-}; do
  "$brew" list --formula "$formula" >/dev/null 2>&1 || "$brew" install "$formula"
done
