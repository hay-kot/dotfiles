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
brew tap hashicorp/tap
brew tap grafana/grafana

# Installing Homebrew Packages
brew install \
  age \
  ansible \
  ansible-lint \
  apr-util \
  atlas \
  bash \
  bat \
  bfg \
  btop \
  cfitsio \
  cmake \
  coreutils \
  crf++ \
  ctop \
  dagger \
  docker \
  editorconfig-checker \
  eza \
  fd \
  fftw \
  fx \
  fzf \
  gh \
  git \
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
  ipython \
  jesseduffield/lazydocker/lazydocker \
  jq \
  k9s \
  kubernetes-cli \
  kustomize \
  lazygit \
  libexif \
  libgit2@1.7 \
  libgsf \
  libimagequant \
  libmatio \
  libproxy \
  libspng \
  mage \
  mas \
  mingw-w64 \
  mise \
  mozjpeg \
  neovim \
  node \
  nss \
  openslide \
  orc \
  pinentry-mac \
  pnpm \
  pre-commit \
  ripgrep \
  sqlc \
  sqlfmt \
  starship \
  stow \
  stylua \
  tmux \
  ttyd \
  typos-cli \
  uv \
  wget \
  wireguard-go \
  yank \
  yq \
  zlib \
  zsh-autosuggestions \
  awscli \
  hashicorp/tap/terraform \
  jsonnet \
  jsonnet-bundler \
  shellcheck \
  tanka \
  helm

# Installing Homebrew Casks
brew install --cask \
  bitwarden \
  brave-browser \
  chromedriver \
  docker \
  cleanshot \
  firefox \
  font-fira-code \
  font-fira-code-nerd-font \
  font-hack-nerd-font \
  font-jetbrains-mono-nerd-font \
  google-chrome \
  gpg-suite-no-mail \
  insomnia \
  jordanbaird-ice \
  keyboard-cleaner \
  obsidian \
  raycast \
  rectangle-pro \
  sublime-text \
  tableplus \
  visual-studio-code \
  vlc \
  wezterm \
  zed \
  zoom \
  1password \
  google-cloud-sdk \
  goland \
  tuple \
  slack

