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
# added now because Homebrew arrives mid-bootstrap (the brew-casks escape
# scripts install it when missing).
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

## Adding things

- **Package**: `mise bootstrap packages use -e personal brew-cask:foo`
  (writes the overlay and installs), or edit the layer file and `dotsync`.
- **Tool**: add to `.config/mise/mise.dev.toml` (or a machine overlay), then
  `mise install` and `mise run lock`.
- **Dotfile**: drop the file in the repo; `mise bootstrap dotfiles apply`.
- **Repo**: add to `mmdot/repos.yml`; mmdot regenerates and runs the clone
  script on the next `dotsync` (working repos are mmdot's job, not
  `[bootstrap.repos]` — that converges checkouts and fights WIP).

## Casks Homebrew still owns

mise can't install casks with complex installer steps. These stay behind
idempotent mmdot-run escape scripts (`setup/brew-casks.*.sh`), and Homebrew
remains installed solely for them: `docker-desktop` (both Macs),
`autodesk-fusion` (personal), `gcloud-cli` (grafana).

A fresh Mac needs no manual Homebrew install — each escape script installs
it when missing.

## Secrets

- **SSH keys** live in 1Password's SSH agent — the agent serves them directly.
- **age identity** at `~/.age/key.txt` decrypts `mmdot/vault.yml` and doubles
  as `SOPS_AGE_KEY_FILE`. Fetch it from 1Password with `op read` — each Mac
  has its own item (`AGE Key MMDOT_<machine>`).
- `mise run mmdot` renders vault-backed templates and then runs the machine's
  setup scripts; `mise run encrypt` / `mise run decrypt` manage the vault.

## Git commit signing

`setup/git.sh` configures SSH commit signing via 1Password's `op-ssh-sign`
and local verification via `gpg.ssh.allowedSignersFile`. Add the signing key
to GitHub/Gitea so hosted commits show as verified.
