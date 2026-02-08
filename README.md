My Dotfiles.

## Setup

Run `./files/bootstrap.sh` to install pre-reqs and then use `mise` tasks for the rest of setup

```sh
chmod +x ./files/bootstrap.sh
./files/bootstrap.sh
```

```sh
mise run setup # initialize setup
mise run mmdot # run mmdot with default tags
```

## AI Skills + Commands

Shared AI content lives in `.ai/`:

- `/.ai/skills` - Claude and Codex skills
- `/.ai/commands` - Claude commands and Codex CLI prompts

Run the AI setup script to wire Claude + Codex:

```sh
./setup/ai.sh
```
