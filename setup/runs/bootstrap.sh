#!/bin/bash

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
  echo "Homebrew not found. Installing Homebrew..."

  # Install Homebrew
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Check if the installation was successful
  if command -v brew &> /dev/null; then
    echo "Homebrew installed successfully!"
  else
    echo "Homebrew installation failed. Please check your setup and try again."
    exit 1
  fi
else
  echo "Homebrew is already installed. Skipping installation."
fi
