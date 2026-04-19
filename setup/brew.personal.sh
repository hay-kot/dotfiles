#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e
# Exit if any command in a pipeline fails (not just the last one)
set -o pipefail
# Treat unset variables as an error when substituting
set -u
# Adding Homebrew Taps
brew tap dagger/tap
brew tap go-task/tap
brew tap hay-kot/gotmpl-tap
brew tap jdxcode/tap
brew tap jesseduffield/lazydocker
brew tap osx-cross/arm
brew tap osx-cross/avr
brew tap hay-kot/dirwatch-tap
brew tap hay-kot/flint-tap
brew tap ariga/tap
brew tap stripe/stripe-cli
brew tap tinygo-org/tools

# Installing Homebrew Packages
brew install \
  age \
  ansible \
  ansible-lint \
  atlas \
  bash \
  bat \
  bfg \
  btop \
  charmbracelet/tap/glow \
  cmake \
  coreutils \
  ctop \
  dagger \
  docker \
  editorconfig-checker \
  eza \
  fd \
  fx \
  fzf \
  gh \
  git \
  git-delta \
  git-lfs \
  gnupg \
  go \
  go-task/tap/go-task \
  gofumpt \
  golang-migrate \
  golangci-lint \
  goose \
  goreleaser \
  gping \
  gum \
  hay-kot/gotmpl-tap/gotmpl \
  hyperfine \
  imagemagick \
  infat \
  ipython \
  jesseduffield/lazydocker/lazydocker \
  jq \
  k9s \
  kubernetes-cli \
  kustomize \
  lazygit \
  mage \
  mas \
  mise \
  mole \
  neovim \
  node \
  pinentry-mac \
  pnpm \
  pre-commit \
  ripgrep \
  semgrep \
  sqlc \
  sqlfmt \
  starship \
  stow \
  stylua \
  tmux \
  tree-sitter-cli \
  ttyd \
  typos-cli \
  uv \
  wget \
  wireguard-go \
  yank \
  yq \
  autorestic \
  bitwarden-cli \
  rbw \
  caddy \
  flyctl \
  mailpit \
  rustup \
  vhs \
  hugo \
  tinygo-org/tools/tinygo \
  stripe/stripe-cli/stripe \
  hay-kot/flint-tap/flint \
  hay-kot/dirwatch-tap/dirwatch

# Installing Homebrew Casks
brew install --cask \
  bitwarden \
  brave-browser \
  chromedriver \
  cleanshot \
  codex \
  firefox \
  font-fira-code \
  font-fira-code-nerd-font \
  font-hack-nerd-font \
  font-jetbrains-mono-nerd-font \
  ghostty \
  google-chrome \
  gpg-suite-no-mail \
  insomnia \
  hiddenbar \
  keyboard-cleaner \
  obsidian \
  opensuperwhisper \
  raycast \
  rectangle-pro \
  sublime-text \
  tableplus \
  visual-studio-code \
  vlc \
  zed \
  zoom \
  aldente \
  bambu-studio \
  autodesk-fusion \
  balenaetcher \
  discord \
  home-assistant \
  orbstack \
  pdf-expert \
  proton-drive \
  protonvpn \
  signal \
  steam \
  transmit \
  zwift

