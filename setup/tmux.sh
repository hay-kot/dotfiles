#!/bin/bash

set -e

# -------------------------------------
# Setup tmux and plugins

echo "tmux: checking installation"
if ! command -v tmux &> /dev/null; then
  echo "tmux: not found, install with: brew install tmux"
  exit 1
fi

echo "tmux: version $(tmux -V)"

# Install TPM (Tmux Plugin Manager)
TPM_DIR="$HOME/.config/tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
  echo "tmux: installing TPM"
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
else
  echo "tmux: TPM already installed"
fi

# Install plugins
echo "tmux: installing plugins"
"$TPM_DIR/bin/install_plugins"

echo "tmux: setup complete"
echo "tmux: reload config with: tmux source ~/.config/tmux/tmux.conf"
