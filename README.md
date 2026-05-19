My Dotfiles.

## New Machine Setup (Personal)

### Phase 0: Prerequisites

1. **Install Xcode Command Line Tools** — `xcode-select --install` (required before Homebrew/git work)
2. **Install Bitwarden desktop app** — log in, enable SSH agent
3. **Install [mise](https://mise.jdx.dev/installing-mise.html)**

### Phase 1: Clone & Bootstrap

```sh
git clone git@github.com:hay-kot/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
mise run full-setup
```

> Optional: run `mise run xcode` to accept the Xcode license and pull any pending system updates.

This runs three sub-tasks in sequence:

1. `files/bootstrap.sh` — installs Homebrew, mise, stow
2. `stow -t ~/ .` — symlinks dotfiles into `$HOME`
3. `mise install` — installs all tools (mmdot, go, node, etc.)

### Phase 2: Retrieve age Key

The age identity at `~/.age/key.txt` is required to decrypt `mmdot/vault.yml`
and is also used as `SOPS_AGE_KEY_FILE`.

```sh
brew install rbw
rbw config set email <your-bitwarden-email>
rbw register && rbw sync
mkdir -p ~/.age
rbw get age-identity > ~/.age/key.txt
chmod 600 ~/.age/key.txt
```

### Phase 3: Run mmdot

```sh
mmdot run @personal   # or @grafana for work machine
```

### Phase 4: Post-Setup

1. **Deploy SSH key to servers** — `ssh-copy-id <host>` for each homelab host
2. **Add SSH public key to GitHub/Gitea** — `ssh-add -L` to get the public key
3. **Git commit signing** — configured by `setup/git.sh` using SSH signing

## SSH Keys

SSH keys are managed via Bitwarden's SSH agent. No key files on disk — the agent serves
keys directly. The CI/Ansible key is stored in Bitwarden but disabled from the SSH agent;
retrieve it with `rbw` when needed.

## Git Commit Signing

`setup/git.sh` configures SSH commit signing and local signature verification with
`gpg.ssh.allowedSignersFile`. Add the signing SSH public key to GitHub/Gitea so hosted
commits show as verified.
