#!/bin/bash

# Exit on errors
set -e

# Variables
HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
OH_MY_ZSH_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
GO_PACKAGE_URL="https://github.com/hay-kot/mmdot"
BREW_PATH="/opt/homebrew/bin/brew"
GO_PATH="/opt/homebrew/bin/go"

# Functions
install_homebrew() {
  if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL $HOMEBREW_INSTALL_URL)"

    # Validate installation
    if command -v brew &> /dev/null; then
      echo "Homebrew installed successfully!"
    else
      echo "Error: Homebrew installation failed. Exiting."
      exit 1
    fi
  else
    echo "Homebrew is already installed. Skipping installation."
  fi
}

install_go_and_mmdot() {
  echo "Installing Go via Homebrew..."
  $BREW_PATH install go || { echo "Error: Failed to install Go."; exit 1; }

  echo "Installing mmdot CLI..."
  $GO_PATH install "$GO_PACKAGE_URL" || { echo "Error: Failed to install mmdot CLI."; exit 1; }
}

# Script execution
echo "Starting setup script..."

install_homebrew
install_go_and_mmdot

echo "Setup complete!"
