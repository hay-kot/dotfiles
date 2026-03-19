#!/bin/bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
AI_ROOT="$DOTFILES_DIR/.ai"
SOURCE_SKILLS="$AI_ROOT/skills"
SOURCE_COMMANDS="$AI_ROOT/commands"

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

# Claude skills/commands/settings are handled by stow.
# Only Codex links need manual setup.
ensure_symlink "$SOURCE_SKILLS" "$CODEX_CLAUDE_LINK"
ensure_symlink "$SOURCE_COMMANDS" "$CODEX_PROMPTS_LINK"

echo "Linked Codex skills: $CODEX_CLAUDE_LINK -> $SOURCE_SKILLS"
echo "Linked Codex prompts: $CODEX_PROMPTS_LINK -> $SOURCE_COMMANDS"
