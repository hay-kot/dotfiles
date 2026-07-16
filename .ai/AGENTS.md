# Agent Instructions

## Working Style

- Default to acting on code and the local environment — edits, tests, local git. Ask before proceeding only for genuine scope changes or hard-to-reverse decisions.
- Never communicate through external systems unless explicitly asked in the current session — no PR or issue comments, review replies, Slack/email messages, or anything another person would read as coming from me. A direct request ("create a PR", "reply to that comment") is the only green light; prior approval of a similar action is not.
- Be direct. No enthusiastic agreement phrases ("You're exactly right!"). Evaluate suggestions on merit, not agreeableness.
- After completing work, state what changed — not anticipated benefits.
- Run formatters, linters, and tests after implementing.

## Architecture Preferences

- Delete old code completely — no deprecation shims, versioned names, or "removed" comments.
- No migration code unless explicitly requested.

## Generated Assets

Store generated markdown files (plans, context, notes) in `.hive/` when available.

`.hive` must ONLY be a symlink, never a regular directory. If it doesn't exist, run `hive ctx init` — never `mkdir`. Once the symlink exists, subdirectories (`plans/`, `research/`, etc.) can be created normally. It points to `$XDG_DATA_HOME/hive/context/<repo-owner>/<repo-name>/`.

To find `.hive/` documents, run exactly `hive ctx ls` (no arguments, no piping) — Glob and standard `ls` do not follow the symlink and fail silently. Then Read the full path from the output.

## Work Tracking

- `hive hc` — track work and manage tasks across sessions. Create issues for non-trivial tasks, update status as work progresses, organize with epics and parent/child hierarchy.
- `ghissues` — LLM-friendly GitHub issue summaries; prefer over raw `gh issue list`. No arguments for the current repo, `--repo owner/name` for an explicit repo.
- `ghcomments` — LLM-friendly PR feedback (reviews, inline comments with file:line and resolved/outdated status, conversation comments); prefer over raw `gh`. No arguments for the current branch's PR, `<number>` for a specific PR, `--type inline --unresolved` for feedback that still needs addressing.

## Task Runners

Run `mi --ls` to list available tasks (`mi` auto-detects Taskfile, Makefile, and mise). Prefer `mi <task-name>` over direct commands — tasks capture project-specific configuration and environment setup. Fall back to direct commands only when no task exists.

## Git Standards

- **Never push to main.** If on main, create a branch before making changes.
- **Branch naming:** `hay-kot/` prefix for repos in the 'grafana' org; otherwise `feat/`, `chore/`, `fix/`.
- **Commit messages:** Clear and concise. Assume readers understand the codebase.
- **Commit signing:** All commits MUST be signed. NEVER bypass signing — no `--no-gpg-sign`, `-c commit.gpgsign=false`, or similar. If signing fails, fix the underlying issue.
- **NEVER @-mention users** on GitHub, Slack, or any platform unless explicitly asked — including PR descriptions, issue bodies, commit messages, and review comments. Reviewer assignments and CODEOWNERS handle notifications.

## Package Manager Security

Package managers enforce a 7-day minimum release age to mitigate supply chain attacks:

- **npm/pnpm:** `~/.npmrc` and `~/.config/pnpm/rc`
- **bun:** `~/.bunfig.toml`
- **uv:** `~/.config/uv/uv.toml`

If an install fails due to `min-release-age`, `minimum-release-age`, or `exclude-newer`, do not bypass it — report the blocked package name and version, then stop. npm also sets `ignore-scripts=true` globally; if a package requires lifecycle scripts to function, flag it rather than disabling the setting.
