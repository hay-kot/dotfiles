#!/bin/bash
set -euo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/.dotfiles}"
AI_ROOT="$DOTFILES_ROOT/.ai"
SOURCE_SKILLS="$AI_ROOT/skills"
SOURCE_COMMANDS="$AI_ROOT/commands"

CLAUDE_DIR="$DOTFILES_ROOT/.claude"
CLAUDE_SKILLS_LINK="$CLAUDE_DIR/skills"
CLAUDE_COMMANDS_LINK="$CLAUDE_DIR/commands"

HOME_CLAUDE_DIR="$HOME/.claude"
HOME_CLAUDE_SKILLS_LINK="$HOME_CLAUDE_DIR/skills"
HOME_CLAUDE_COMMANDS_LINK="$HOME_CLAUDE_DIR/commands"

CODEX_SKILLS_DIR="$HOME/.codex/skills"
CODEX_CLAUDE_LINK="$CODEX_SKILLS_DIR/claude"
CODEX_PROMPTS_LINK="$HOME/.codex/prompts"

if [ ! -d "$SOURCE_SKILLS" ]; then
  echo "Missing skills directory: $SOURCE_SKILLS" >&2
  exit 1
fi

if [ ! -d "$SOURCE_COMMANDS" ]; then
  echo "Missing commands directory: $SOURCE_COMMANDS" >&2
  exit 1
fi

mkdir -p "$CLAUDE_DIR"
mkdir -p "$HOME_CLAUDE_DIR"
mkdir -p "$CODEX_SKILLS_DIR"

ensure_symlink() {
  local target="$1"
  local link="$2"

  if [ -e "$link" ] && [ ! -L "$link" ]; then
    echo "Refusing to replace non-symlink path: $link" >&2
    exit 1
  fi

  ln -sfn "$target" "$link"
}

ensure_symlink "$SOURCE_SKILLS" "$CLAUDE_SKILLS_LINK"
ensure_symlink "$SOURCE_COMMANDS" "$CLAUDE_COMMANDS_LINK"

ensure_symlink "$SOURCE_SKILLS" "$HOME_CLAUDE_SKILLS_LINK"
ensure_symlink "$SOURCE_COMMANDS" "$HOME_CLAUDE_COMMANDS_LINK"

ensure_symlink "$SOURCE_SKILLS" "$CODEX_CLAUDE_LINK"
ensure_symlink "$SOURCE_COMMANDS" "$CODEX_PROMPTS_LINK"

echo "Linked Claude (dotfiles): $CLAUDE_SKILLS_LINK -> $SOURCE_SKILLS"
echo "Linked Claude (dotfiles): $CLAUDE_COMMANDS_LINK -> $SOURCE_COMMANDS"
echo "Linked Claude (home): $HOME_CLAUDE_SKILLS_LINK -> $SOURCE_SKILLS"
echo "Linked Claude (home): $HOME_CLAUDE_COMMANDS_LINK -> $SOURCE_COMMANDS"
echo "Linked Codex skills: $CODEX_CLAUDE_LINK -> $SOURCE_SKILLS"
echo "Linked Codex prompts: $CODEX_PROMPTS_LINK -> $SOURCE_COMMANDS"
