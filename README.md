My Dotfiles.

## New Machine Setup (Personal)

### Phase 0: Prerequisites

1. **Install Bitwarden desktop app** — log in, enable SSH agent
2. **Install [mise](https://mise.jdx.dev/installing-mise.html)**

### Phase 1: Clone & Bootstrap

```sh
git clone git@github.com:hay-kot/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
mise run full-setup
```

This runs three sub-tasks in sequence:

1. `files/bootstrap.sh` — installs Homebrew, mise, stow
2. `stow -t ~/ .` — symlinks dotfiles into `$HOME`
3. `mise install` — installs all tools (mmdot, go, node, etc.)

### Phase 2: Retrieve age Key

The age identity at `~/.age/mmdot_mbp_personal` is required to decrypt `mmdot/vault.yml`.

```sh
brew install rbw
rbw config set email <your-bitwarden-email>
rbw register && rbw sync
mkdir -p ~/.age
rbw get age-identity > ~/.age/mmdot_mbp_personal
chmod 600 ~/.age/mmdot_mbp_personal
```

### Phase 3: Run mmdot

```sh
mmdot run @personal   # or @grafana for work machine
```

### Phase 4: Post-Setup

1. **Deploy SSH key to servers** — `ssh-copy-id <host>` for each homelab host
2. **Add SSH public key to GitHub/Gitea** — `ssh-add -L` to get the public key
3. **GPG key** — generate a fresh key (see below)

## SSH Keys

SSH keys are managed via Bitwarden's SSH agent. No key files on disk — the agent serves
keys directly. The CI/Ansible key is stored in Bitwarden but disabled from the SSH agent;
retrieve it with `rbw` when needed.

## GPG Keys

Generate a fresh key on each new machine rather than transferring.

```sh
gpg --full-generate-key  # RSA 4096, no expiry or your preference
gpg --list-secret-keys --keyid-format long  # note the new KEY_ID
gpg --armor --export KEY_ID  # copy to GitHub → Settings → SSH and GPG keys
git config --global user.signingkey KEY_ID
git config --global commit.gpgsign true
```

Revoke the old key after confirming the new one works:

```sh
gpg --edit-key OLD_KEY_ID revkey
# Remove the old key from GitHub
```
