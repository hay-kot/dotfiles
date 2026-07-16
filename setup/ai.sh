#!/bin/bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
AI_ROOT="$DOTFILES_DIR/.ai"
SOURCE_SKILLS="$AI_ROOT/skills"

CODEX_SKILLS_DIR="$HOME/.codex/skills"
CODEX_CLAUDE_LINK="$CODEX_SKILLS_DIR/claude"

if [ ! -d "$SOURCE_SKILLS" ]; then
  echo "Missing skills directory: $SOURCE_SKILLS" >&2
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

# Pi extensions, skills, and settings.
# Stow can't manage ~/.pi as a single symlink because it contains local
# state (auth.json, sessions/, run-history.jsonl). Individual items are
# symlinked instead.
PI_AGENT_DIR="$HOME/.pi/agent"
mkdir -p "$PI_AGENT_DIR"

ensure_symlink "$DOTFILES_DIR/.pi/agent/AGENTS.md" "$PI_AGENT_DIR/AGENTS.md"
ensure_symlink "$DOTFILES_DIR/.pi/agent/settings.json" "$PI_AGENT_DIR/settings.json"
ensure_symlink "$DOTFILES_DIR/.pi/agent/models.json" "$PI_AGENT_DIR/models.json"
ensure_symlink "$DOTFILES_DIR/.pi/agent/skills" "$PI_AGENT_DIR/skills"
ensure_symlink "$DOTFILES_DIR/.pi/agent/extensions" "$PI_AGENT_DIR/extensions"
ensure_symlink "$DOTFILES_DIR/.pi/agent/agents" "$PI_AGENT_DIR/agents"

echo "Linked Pi agent config: $PI_AGENT_DIR"

# Codex links need manual setup.
ensure_symlink "$SOURCE_SKILLS" "$CODEX_CLAUDE_LINK"

echo "Linked Codex skills: $CODEX_CLAUDE_LINK -> $SOURCE_SKILLS"

# Global agent instructions. Root AGENTS.md/CLAUDE.md are repo-local docs,
# so they are excluded from stow via .stow-local-ignore; the global file
# lives in .ai/ and is linked here instead.
ensure_symlink "$AI_ROOT/AGENTS.md" "$HOME/AGENTS.md"

echo "Linked global agent instructions: $HOME/AGENTS.md -> $AI_ROOT/AGENTS.md"
