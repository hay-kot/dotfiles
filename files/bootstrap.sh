#!/bin/bash
# Exit on errors
set -e

# Variables
HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
BREW_PATH="/opt/homebrew/bin/brew"

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

install_homebrew() {
  if ! command -v brew &> /dev/null; then
    log_info "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL $HOMEBREW_INSTALL_URL)"
    
    # Validate installation
    if command -v brew &> /dev/null; then
      log_info "Homebrew installed successfully!"
    else
      log_error "Homebrew installation failed. Exiting."
      exit 1
    fi
  else
    log_info "Homebrew is already installed. Skipping installation."
  fi
}

install_brew_package() {
  local package_name=$1
  local tap=$2
  
  # Add tap if provided
  if [ -n "$tap" ]; then
    if ! $BREW_PATH tap | grep -q "^${tap}$"; then
      log_info "Adding tap: $tap"
      $BREW_PATH tap "$tap" || { log_error "Failed to add tap $tap"; exit 1; }
    fi
  fi
  
  # Check if package is already installed
  if $BREW_PATH list "$package_name" &> /dev/null; then
    log_info "$package_name is already installed. Skipping."
  else
    log_info "Installing $package_name..."
    $BREW_PATH install "$package_name" || { log_error "Failed to install $package_name"; exit 1; }
    log_info "$package_name installed successfully!"
  fi
}

# Script execution
log_info "Starting setup script..."

# Install Homebrew
install_homebrew

# Install mise
install_brew_package "mise"

log_info "Setup complete!"
