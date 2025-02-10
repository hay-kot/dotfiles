#!/bin/bash

set -e

# -------------------------------------
# Setup Common Directories

make_dir() {
  # Log directory creation
  echo "dirs: $1"

  # Create the directory and any necessary parent directories
  mkdir -p "$1"
}

# Define the directories to create
devdirs=(
  "$HOME/code/repos"
  "$HOME/code/prs"
  "$HOME/code/zarchive"
  "$HOME/code/temp"
)

# Create each directory
for dir in "${devdirs[@]}"; do
  make_dir "$dir"
done
