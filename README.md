My Dotfiles.

## Setup

Run `./files/bootstrap.sh` to install pre-reqs and then use the `Taskfile.yml` to run any other setup commands

```sh
chmod +x ./files/bootstrap.sh
./files/bootstrap.sh
```

```sh
task setup # initialize setup
task run -- personal # mmdot personal group
```

## AI Skills + Commands

Shared AI content lives in `.ai/`:

- `/.ai/skills` - Claude and Codex skills
- `/.ai/commands` - Claude commands and Codex CLI prompts

Run the AI setup script to wire Claude + Codex:

```sh
./setup/ai.sh
```
