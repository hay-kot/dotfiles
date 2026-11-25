# Dotfiles Conventions

Repo-specific rules for this dotfiles repository. Global agent instructions live in `.ai/AGENTS.md` (symlinked to `~/AGENTS.md` and `~/.claude/CLAUDE.md`).

## Dotfile Deployment Is Opt-In

Symlinks into `$HOME` are managed by the `[dotfiles]` section in `mise.toml` —
only listed entries deploy. Adding a new top-level dotfile to the repo does
NOT deploy it; add an explicit `[dotfiles]` entry for it. Directories under
`~/.config` need no new entry (`~/.config` is `symlink-each`, so files added
beneath it deploy on the next apply).

Finder Quick Actions are `.workflow` bundles in `files/services/`, each with
its own whole-bundle entry in `mise.dev.toml` (Automator cannot load a bundle
whose inner files are symlinks, so `symlink-each` does not work for them).

## TruffleHog Config

Custom detectors live in `.config/trufflehog/config.yaml` (deployed to `~/.config/trufflehog/config.yaml` via mise `[dotfiles]`).
All trufflehog call sites check for this file and pass `--config` when present.
Add new detectors to the config file — do not hardcode patterns in scripts.

## Agent Observability Credentials

`~/.config/agento11y/config.env` is rendered by `setup/agento11y.sh` from the
1Password item in `AGENTO11Y_OP_ITEM`. It holds the token at 0600 and `dotsync`
overwrites it, so fix credentials in 1Password, not in the file.

Never run `agento11y login` — it hand-writes that file and the next converge
discards the change.

## PR Assets (pra)

`.config/prassets/config.yaml` lists the repos that may upload to the public
PR asset bucket; there is no default entry on purpose. Never add a work or
private repo. `setup/prassets.sh` copies the R2 key from 1Password into the
login keychain (service `pra-agent-assets`); fix it in 1Password, not in the
keychain.
The agent skill is `src/pr-record/SKILL.md`, copied into each repo that uses
pra (or linked by a hive rule, see `.config/hive/scripts/link-skill.sh`), not
shared through `.ai/skills/`. README "PR screenshots and
recordings" has the setup.

## Docker Engines

OrbStack and Docker Desktop are both installed. `bin/docker-use orb|desktop`
switches the engine, the docker context, and the `/var/run/docker.sock` link
together.

Do not export `DOCKER_HOST` in shell config. It overrides `docker context use`,
and a tmux server keeps it in its global environment until the server restarts.

## Window Management (winctl)

Hotkey window placement is `winctl` (`src/winctl/`), run by Raycast Script
Commands in `.config/raycast/scripts/`. Read `src/winctl/README.md` before
changing either: it lists the workflows, the setup steps that live outside
the repo (Raycast hotkeys), and why Hammerspoon, Rectangle Pro layouts, and a
Raycast extension were rejected.
