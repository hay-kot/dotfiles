# Dotfiles Conventions

Repo-specific rules for this dotfiles repository. Global agent instructions live in `.ai/AGENTS.md` (symlinked to `~/AGENTS.md` and `~/.claude/CLAUDE.md`).

## Dotfile Deployment Is Opt-In

Symlinks into `$HOME` are managed by the `[dotfiles]` section in `mise.toml` —
only listed entries deploy. Adding a new top-level dotfile to the repo does
NOT deploy it; add an explicit `[dotfiles]` entry for it. Directories under
`~/.config` need no new entry (`~/.config` is `symlink-each`, so files added
beneath it deploy on the next apply).

## Logging

Tools in `bin/` that produce persistent logs write to `~/.local/dotlogs/<toolname>.log`.
Never use `~/.local/log/` or any other path. Log lines must include a UTC timestamp.

## TruffleHog Config

Custom detectors live in `.config/trufflehog/config.yaml` (deployed to `~/.config/trufflehog/config.yaml` via mise `[dotfiles]`).
All trufflehog call sites check for this file and pass `--config` when present.
Add new detectors to the config file — do not hardcode patterns in scripts.
