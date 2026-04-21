#!/bin/bash
set -euo pipefail

# Adding Homebrew Taps
brew tap dagger/tap
brew tap go-task/tap
brew tap hay-kot/gotmpl-tap
brew tap jdxcode/tap
brew tap jesseduffield/lazydocker
brew tap osx-cross/arm
brew tap osx-cross/avr
brew tap hashicorp/tap
brew tap grafana/grafana

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
  awscli \
  azure-cli \
  hashicorp/tap/terraform \
  jsonnet \
  jsonnet-bundler \
  shellcheck \
  tanka \
  helm \
  zizmor

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
  1password \
  docker-desktop \
  gcloud-cli \
  google-cloud-sdk \
  goland \
  slack \
  tailscale-app \
  tuple \
  zen