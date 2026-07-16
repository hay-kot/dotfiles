# Dotfiles Conventions

Repo-specific rules for this dotfiles repository. Global agent instructions live in `.ai/AGENTS.md` (symlinked to `~/AGENTS.md` and `~/.claude/CLAUDE.md`).

## Logging

Tools in `bin/` that produce persistent logs write to `~/.local/dotlogs/<toolname>.log`.
Never use `~/.local/log/` or any other path. Log lines must include a UTC timestamp.

## TruffleHog Config

Custom detectors live in `.config/trufflehog/config.yaml` (stow-managed to `~/.config/trufflehog/config.yaml`).
All trufflehog call sites check for this file and pass `--config` when present.
Add new detectors to the config file — do not hardcode patterns in scripts.
