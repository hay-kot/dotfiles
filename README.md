My Dotfiles.

## New Machine Setup

### Prerequisites

1. Install [mise](https://mise.jdx.dev/installing-mise.html)
2. Transfer keys from old machine (see Key Backup & Restore below)

### Setup

```sh
git clone git@github.com:hay-kot/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
mise run full-setup
mmdot run @personal   # or @grafana for work machine
```

## Key Backup & Restore

### age Key (mmdot vault decryption)

The age identity at `~/.age/mmdot_mbp_personal` is required to decrypt `mmdot/vault.yml`.

**Backup (old machine):**
```sh
cp ~/.age/mmdot_mbp_personal /Volumes/USB/age-key.txt
```

**Restore (new machine):**
```sh
mkdir -p ~/.age
cp /Volumes/USB/age-key.txt ~/.age/mmdot_mbp_personal
chmod 600 ~/.age/mmdot_mbp_personal
```

### GPG Keys (rotate on migration)

Generate a fresh key on the new machine rather than transferring the old private key.

**New machine:**
```sh
gpg --full-generate-key  # RSA 4096, no expiry or your preference
gpg --list-secret-keys --keyid-format long  # note the new KEY_ID
gpg --armor --export KEY_ID  # copy output to GitHub → Settings → SSH and GPG keys
git config --global user.signingkey KEY_ID
git config --global commit.gpgsign true
```

**Old machine (after new key is confirmed working):**
```sh
gpg --list-secret-keys --keyid-format long  # find old KEY_ID
gpg --edit-key OLD_KEY_ID revkey  # revoke
# Remove the old key from GitHub
```

### SSH Keys

**Backup (old machine):**
```sh
cp -r ~/.ssh /Volumes/USB/ssh-backup
```

**Restore (new machine):**
```sh
cp -r /Volumes/USB/ssh-backup/* ~/.ssh/
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub
```
