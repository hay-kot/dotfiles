# Dotfiles

Machine configuration for three machine classes. mise
[bootstrap](https://mise.jdx.dev/bootstrap.html) owns the declarative surface —
packages, dotfiles, repos, tools. [mmdot](https://github.com/hay-kot/mmdot)
owns the imperative surface: tagged setup scripts (`exec:`), Go-template
rendering (agent files, ssh config, env secrets), and the age vault. They meet
in one command: `mise bootstrap` ends by running `mmdot run @<machine tag>`.

The daily command on every machine is **`dotsync`** — run it anytime; it is
idempotent and only changes what drifted:

```sh
dotsync                  # git pull --autostash --ff-only + mise bootstrap --yes (+ mmdot)
mise bootstrap plan      # read-only preview of what dotsync would change
```

On Macs a sync may prompt for sudo once (mac preference scripts) — expected,
never destructive. The server converges unattended (its privileged
prerequisites — apt packages, login shell — happen once, in step 0 of its
setup).

| Machine | `MISE_ENV` | Config layers |
|---|---|---|
| server (Linux) | `server` | `mise.toml` + `mise.server.toml` |
| personal (Mac) | `dev,personal` | `mise.toml` + `mise.dev.toml` + `mise.personal.toml` |
| grafana (Mac) | `dev,grafana` | `mise.toml` + `mise.dev.toml` + `mise.grafana.toml` |

The env list is pinned per machine in `~/.config/mise/miserc.toml` by
`mise run stamp` — after that, `MISE_ENV` is never typed again on that machine.
Global tool sets layer the same way via `~/.config/mise/mise.<env>.toml`
(deployed by the `[dotfiles]` section itself).

## New Mac — personal

```sh
xcode-select --install                   # GUI installer; wait for it to finish:
until xcode-select -p >/dev/null 2>&1; do sleep 10; done
curl https://mise.run | sh
# The installer does not touch the current shell's PATH; /opt/homebrew/bin is
# added now because Homebrew arrives mid-bootstrap (the brew package escape
# script installs it when missing).
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
mkdir -p ~/code/repos                    # git clone won't create parent dirs
# HTTPS clone: the 1Password SSH agent doesn't exist yet
git clone https://github.com/hay-kot/dotfiles.git ~/code/repos/dotfiles
cd ~/code/repos/dotfiles
mise trust
# First bootstrap SKIPS repos AND the bootstrap task: [bootstrap.repos] URLs
# are SSH and the 1Password agent doesn't exist yet (a failed clone aborts
# the whole run), and the task runs mmdot, whose vault-backed templates need
# the age key — fetched after 1Password sign-in below.
MISE_ENV=dev,personal mise bootstrap --yes --skip repos,task
MISE_ENV=dev,personal mise run stamp
```

Then:

1. **Sign in to 1Password** (GUI app installed by bootstrap); enable the SSH
   agent and CLI integration; verify `ssh-add -L` lists a key. SSH keys and
   commit signing come from it — no key files on disk.
2. Fetch this machine's age identity from 1Password:
   ```sh
   mkdir -p ~/.age
   op read 'op://Private/AGE Key MMDOT_MBP_PERSONAL/AGE/private key' > ~/.age/key.txt
   chmod 600 ~/.age/key.txt
   ```
3. `mise bootstrap --yes` — the full run: repos clone now that the agent
   serves keys, and step 10 runs `mmdot run @personal` (vault-backed
   templates, then setup scripts — unlocked by the age key).
4. Flip the dotfiles remote to SSH now that the agent works:
   `git remote set-url origin git@github.com:hay-kot/dotfiles.git`
5. Post-setup: `ssh-copy-id` to homelab hosts; add the signing public key
   (`ssh-add -L`) to GitHub/Gitea so commits show verified.

## Existing Mac — grafana adoption

The work Mac migrates in place — see
[docs/adopt-existing-mac.md](docs/adopt-existing-mac.md) for the full
runbook (identity pin first, folded-link removal, MDM preflight, cask
transfer). The fresh-Mac sequence below is for a wiped/replacement machine.

## New Mac — grafana

Its own explicit sequence — not "personal with the env swapped" — because the
age step is machine-specific: each Mac fetches its own 1Password item.

```sh
xcode-select --install
until xcode-select -p >/dev/null 2>&1; do sleep 10; done
curl https://mise.run | sh
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
mkdir -p ~/code/repos
git clone https://github.com/hay-kot/dotfiles.git ~/code/repos/dotfiles
cd ~/code/repos/dotfiles
mise trust
MISE_ENV=dev,grafana mise bootstrap --yes --skip repos,task
MISE_ENV=dev,grafana mise run stamp
```

Then:

1. **Sign in to 1Password**; enable the SSH agent and CLI integration; verify
   `ssh-add -L` lists a key.
2. Fetch **this machine's own** age identity (naming pattern
   `AGE Key MMDOT_<machine>` — never the personal item):
   ```sh
   mkdir -p ~/.age
   op read 'op://Private/AGE Key MMDOT_<machine>/AGE/private key' > ~/.age/key.txt
   chmod 600 ~/.age/key.txt
   ```
3. `mise bootstrap --yes` — the full run; step 10 runs `mmdot run @grafana`.
4. `git remote set-url origin git@github.com:hay-kot/dotfiles.git`

## New Server

```sh
# Privileged prerequisites, once: clone needs git, the installer needs curl,
# the deployed shell config is zsh — and the login shell is set HERE (chsh
# run later, unprivileged, can hit a PAM password prompt and break the
# unattended bootstrap).
sudo apt-get update && sudo apt-get install -y git curl zsh
sudo chsh -s /usr/bin/zsh "$USER"

curl https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"
git clone https://github.com/hay-kot/dotfiles ~/.dotfiles
cd ~/.dotfiles
mise trust
MISE_ENV=server mise bootstrap --yes   # unattended from here on
MISE_ENV=server mise run stamp
```

## Converging a machine

`dotsync` is THE daily command, on every machine — idempotent, run it anytime,
it only changes what drifted. It is an alias (defined in the shared `.zshrc`
path, so it exists on the Linux server too) for the repo-local `sync` task,
which bare `mise run sync` can't reach from `$HOME`:

```sh
dotsync                           # alias: mise -C "${DOTFILES_DIR:-$HOME/.dotfiles}" run sync
mise bootstrap plan               # read-only preview: create / update / unchanged / remove
mise bootstrap dotfiles status    # applied / missing / differs
mise bootstrap packages import    # capture ad-hoc installs into config
```

On Macs a sync may prompt for sudo once (mac preference scripts) and re-runs
mmdot's setup scripts — they are re-runnable by design. The server has no
step-10 task, so `dotsync` runs unattended there (its privileged
prerequisites were satisfied once, at setup).

The `git pull` is best-effort — an unreachable remote (no network, a dead
SSH agent) or a diverged branch prints a warning and the bootstrap still
runs against whatever config is checked out.

## Adding things

- **Package**: `mise bootstrap packages use -e personal brew-cask:foo`
  (writes the overlay and installs), or edit the layer file and `dotsync`.
- **Tool**: add to `.config/mise/mise.dev.toml` (or a machine overlay), then
  `mise install` and `mise run lock`.
- **Dotfile**: drop the file in the repo; `mise bootstrap dotfiles apply`.
- **Finder Quick Action**: put the `.workflow` bundle in `files/services/` and
  add a whole-bundle `[dotfiles]` entry in `mise.dev.toml`; `mise bootstrap
  dotfiles apply` links it into `~/Library/Services`.
- **Repo**: add to `mmdot/repos.yml`; mmdot regenerates and runs the clone
  script on the next `dotsync` (working repos are mmdot's job, not
  `[bootstrap.repos]` — that converges checkouts and fights WIP).

## Packages that use the Homebrew CLI

mise reads Homebrew taps through the GitHub API, so it can't read a private
tap without an SSO-authorized token. Formulas from those taps stay behind the
idempotent mmdot-run escape script (`setup/brew-packages.sh`): today that is
only `agento11y` (both Macs). Every cask, including ones with pkg or script
installers, is declared in `[bootstrap.packages]`.

A fresh Mac needs no manual Homebrew or tap setup -- the escape script installs
Homebrew when missing, and a fully qualified formula name adds its tap.

## Secrets

- **SSH keys** live in 1Password's SSH agent — the agent serves them directly.
- **age identity** at `~/.age/key.txt` decrypts `mmdot/vault.yml` and doubles
  as `SOPS_AGE_KEY_FILE`. Fetch it from 1Password with `op read` — each Mac
  has its own item (`AGE Key MMDOT_<machine>`).
- `mise run mmdot` renders vault-backed templates and then runs the machine's
  setup scripts; `mise run encrypt` / `mise run decrypt` manage the vault.

## Pi extensions

Local extensions add managed background shells, Claude-style `/goal`, and a
structured question UI. See [Pi extensions](docs/pi-extensions.md) for commands,
limits, and checks. `setup/ai.sh` deploys the extension directory; run `/reload`
in Pi to load changes.

## Coding agent observability

`claude` and `pi` sessions are recorded by [Grafana Agent observability][o11y]
(the `agento11y` CLI, formerly `sigil`). Model calls, tokens, cost, tool calls,
and conversation content land in the personal Grafana Cloud stack.

Capture is done by host plugins — the `agento11y-claude-code` Claude Code plugin
and the `@grafana/agento11y-pi` extension — registered in `.claude/settings.json`
and `.pi/agent/settings.json`, both symlinked into this repo so the versions stay
tracked. Nothing wraps or shadows the agents; `claude` and `pi` are the real
binaries and are started normally.

`setup/brew-packages.sh` installs the CLI from Grafana's Homebrew tap because
the tap is private and mise cannot read it. No manual tap setup is
needed. `setup/agento11y.sh` then renders
`~/.config/agento11y/config.env` (0600) from the 1Password item named by
`AGENTO11Y_OP_ITEM` and registers both plugins. It re-runs on every `dotsync`,
so edit the 1Password item and converge — the file
is a rendered copy, the same arrangement as the age identity at
`~/.age/key.txt`.

Do not run `agento11y login`. It writes the same file by hand and the next
`dotsync` overwrites it.

Missing item, locked vault, or no `op` leaves the file absent: agents run
normally and the plugin records nothing.

Setup is once per stack, not once per machine. Take the values from Grafana
Cloud (Agent Observability → the setup-coding-agent page). Read the token into
a variable first so it never lands in shell history:

```sh
printf 'token: ' >&2; IFS= read -rs TOKEN; echo >&2

op item create --category "API Credential" --title agento11y --vault Private \
  "endpoint[text]=https://agento11y-prod-<region>.grafana.net" \
  "tenant_id[text]=<instance-id>" \
  "otlp_endpoint[text]=https://otlp-gateway-prod-<region>.grafana.net/otlp" \
  "credential[concealed]=$TOKEN"

unset TOKEN
```

The field labels matter — `setup/agento11y.sh` looks them up by name. The token
needs the `sigil:write`, `metrics:write`, and `traces:write` scopes. Then
`dotsync`, and check with `agento11y doctor`.

Content capture is `full`, so prompts, responses, and tool I/O leave the
machine (the SDK redacts known secret formats first). Set
`AGENTO11Y_CONTENT_CAPTURE_MODE=metadata_only` in `files/<machine>.local.env`
to send only tokens, cost, timing, and tool names.

[o11y]: https://grafana.com/docs/grafana-cloud/machine-learning/ai-observability/

## PR screenshots and recordings

Agents attach screenshots and screen recordings to PRs with [pra](https://github.com/hay-kot/prassets), which uploads to a public R2 bucket and prints stable URLs. It is opt-in per repo, because anything uploaded is public.

- `pra` and the Playwright that `pr-record` falls back to come from `.config/mise/mise.personal.toml`, so only the personal Mac has them.
- `.config/prassets/config.yaml` names the bucket and lists the repos that may upload. There is no `default:` entry, so an unlisted repo gets an error. Never list a work or private repo.
- `setup/prassets.sh` copies the R2 key from the 1Password item in `PRASSETS_OP_ITEM` (`files/personal.local.env`) into the login keychain (service `pra-agent-assets`) on every `dotsync`. The config reads it with `security find-generic-password`, so the key is never a plaintext file and pra keeps working while 1Password is locked. It does need a logged-in GUI session: over SSH the login keychain is locked.
- `bin/pr-record` records a scripted Playwright walk through a web app to an MP4 and a poster, and `--upload` puts both with pra. The code is in `src/pr-record/`.
- `src/pr-record/SKILL.md` is the agent skill. It is not in `.ai/skills/` on purpose: copy it into each repo that uses pra.

Keys use hive-style partitions: `type=pr/host=<host>/owner=<owner>/repo=<repo>/branch=<branch>/<file>`. pra always puts a repo's prefix first, so a shared leading `type=pr/` is the only way one lifecycle rule covers every repo.

### Enable a repo

1. Add a line under `repos:` in `.config/prassets/config.yaml`: `github.com/<owner>/<repo>: *pr-assets`.
2. Copy `src/pr-record/SKILL.md` to `.claude/skills/pr-assets/SKILL.md` in that repo. For a repo where only I use pra, commit nothing there: add a hive rule that runs `.config/hive/scripts/link-skill.sh`, as the colonyops/hive rule in `.config/hive/config.yaml` does. Each new or recycled session links the skill and hides it from git in `.git/info/exclude`.
3. Run `pra config check` in a checkout of the repo.

### Set up the bucket (once)

The bucket exists with the r2.dev URL and the lifecycle rule below. Steps 1 to 3 record how it was made.

1. Create the bucket in the Cloudflare account whose ID is in the config's `endpoint`: `wrangler r2 bucket create agent-pr-assets`.
2. Turn on public access: `wrangler r2 bucket dev-url enable agent-pr-assets`. That URL is `public_url` in `.config/prassets/config.yaml`.
3. Expire PR assets after 30 days: `wrangler r2 bucket lifecycle add agent-pr-assets expire-pr-assets type=pr/ --expire-days 30 --abort-multipart-days 7`.
4. Create an R2 API token (R2 > Manage API tokens) with Object Read & Write on `agent-pr-assets` only, then store it. Read the secret into a variable so it never lands in shell history:

   ```sh
   printf 'secret access key: ' >&2; IFS= read -rs SECRET; echo >&2

   op item create --category "API Credential" --title pra-agent-assets --vault Private \
     "access_key_id[text]=<access key id>" \
     "secret_access_key[concealed]=$SECRET"

   unset SECRET
   ```

   The field labels matter: `setup/prassets.sh` looks them up by name.
5. Run `dotsync`, then `pra config check` in a checkout of an enabled repo.

## Git commit signing

`setup/git.sh` configures SSH commit signing via 1Password's `op-ssh-sign`
and local verification via `gpg.ssh.allowedSignersFile`. Add the signing key
to GitHub/Gitea so hosted commits show as verified.
