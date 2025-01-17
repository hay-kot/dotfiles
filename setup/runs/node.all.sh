#!/bin/bash

set -e

# -------------------------------------
# Setup common packages

install_pkg() {
  # Log directory creation
  echo "node: installing package $1"

  # Create the directory and any necessary parent directories
  npm install --global $1
}

# Define the directories to create
pkgs=(
  "eslint"
  "typescript"
  "ts-node"
  "pnpm"
  "yarn"
)

# Create each directory
for dir in "${pkgs[@]}"; do
  install_pkg "$dir"
done
