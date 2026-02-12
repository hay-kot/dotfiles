#!/bin/bash

set -e

# -------------------------------------
# Git Identity

echo "git: setting user.name"
git config --global user.name Hayden

echo "git: setting user.email"
git config --global user.email 64056131+hay-kot@users.noreply.github.com

# -------------------------------------
# Git Global Ignore File

echo "git: copy global git ignore"
cp ./files/global.gitignore $HOME/.gitignore_global

echo "git: setting core.excludesFile to $HOME/.gitignore_global"
git config --global core.excludesFile "$HOME/.gitignore_global"

# -------------------------------------
# Git Config
#

echo "git: enable rerere"
git config --global rerere.enabled true

echo "git: set default editor"
git config --global core.editor nvim

# -------------------------------------
# Git Aliases
#

# Function to set a Git configuration value globally
set_git_alias() {
  local key="$1"
  local value="$2"
  git config --global "$key" "$value"
  echo "git: set alias $key -> $value"
}

# Define Git aliases as a plain array (no associative array to avoid issues with special characters)
aliases=(
  "alias.aliases=!git config --list | grep 'alias\\.' | sed 's/alias\\.\\([^=]*\\)=\\(.*\\)/\\1\\ \t => \\2/' | sort"
  "alias.st=status"
  "alias.gone=!git fetch -p && git branch -vv | grep 'origin/.*: gone]' | awk '{print \$1}' | xargs git branch -D"
  "alias.gmm=!git checkout \$(git_main_branch) && git pull && git checkout - && git merge main"
  "alias.grm=!git checkout \$(git_main_branch) && git pull && git checkout - && git rebase main"
)

# Loop through the aliases and set them
for alias in "${aliases[@]}"; do
  key=$(echo "$alias" | cut -d'=' -f1)
  value=$(echo "$alias" | cut -d'=' -f2-)
  set_git_alias "$key" "$value"
done

