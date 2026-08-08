#!/usr/bin/env bash
set -euo pipefail

# Casks mise can't install (complex installer steps) — Homebrew stays
# installed solely for these. Fresh Macs have no Homebrew; the guard
# installs it (files/bootstrap.sh, which used to, is deleted).
command -v brew >/dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Absolute path: if the guard just installed Homebrew, this process's
# PATH doesn't include it yet.
brew=/opt/homebrew/bin/brew
for cask in gcloud-cli; do
  "$brew" list --cask "$cask" >/dev/null 2>&1 || "$brew" install --cask "$cask"
done
