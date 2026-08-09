# Adopting an existing Mac (grafana runbook)

In-place migration of a stow/brew-managed Mac onto the mise bootstrap setup.
Written after the personal machine's migration (2026-08-08) — the warnings
below are lessons from that run, not theory. Run the cask-transfer section
inside tmux (Ghostty's bundle gets swapped mid-run).

## 1. Pin identity BEFORE pulling

The pull delivers the settings-only global mise config; without the pin,
every new shell loses go/node until the overlay layers activate.

```sh
mkdir -p ~/.config/mise
printf 'env = ["dev", "grafana"]\n' > ~/.config/mise/miserc.toml
```

## 2. Pull and trust

```sh
cd ~/code/repos/dotfiles && git switch main && git pull --ff-only
mise trust
zsh -ic 'command -v go node'    # must still resolve — proves the pin worked
```

Kill stale mise binaries — an old `~/.local/bin/mise` shadowed the brew one
on the personal machine and broke everything confusingly:

```sh
rm -f ~/.local/bin/mise
brew upgrade mise               # needs >= 2026.8.2
```

## 3. Remove folded stow links BEFORE applying dotfiles

**Do not skip.** Stow leaves whole-directory symlinks (`~/.config/nvim ->
repo/.config/nvim`). `mise bootstrap dotfiles apply` writes *through* them,
replacing repo source files with self-symlink loops. Tracked files are
recoverable via git; gitignored ones (tmux plugins, app caches) are not.

```sh
# enumerate: dir links pointing into the repo
for l in $(find "$HOME" -maxdepth 1 -type l) \
         $(find "$HOME/.config" -maxdepth 1 -type l) \
         $(find "$HOME/.claude" -maxdepth 1 -type l 2>/dev/null); do
  t=$(readlink "$l"); case "$t" in *dotfiles*) [ -d "$l" ] && echo "$l -> $t";; esac
done
# review the list, then remove each printed link (rm — they're just links)
```

Then apply and verify the repo stayed clean:

```sh
mise bootstrap dotfiles apply --force
mise bootstrap dotfiles status            # all "applied"
git -C ~/code/repos/dotfiles status --porcelain   # MUST be empty — if T entries
                                          # appear, a folded link was missed:
                                          # remove it, git restore ., re-apply
```

## 4. MDM preflight (work Mac)

Classify every declared cask (`mise bootstrap packages status`) as
brew-owned / MDM-managed / manual. Rules:

- A shared dev cask that is MDM-owned here **moves** its declaration from
  `mise.dev.toml` to `mise.personal.toml` (never delete from dev — that
  strips the personal machine). Grafana-only MDM casks: delete from
  `mise.grafana.toml`. Commit the edits.
- MDM-locked `defaults` values are expected drift — trim conflicting lines
  from `setup/mac.*.sh` rather than fighting the MDM.
- Record MDM-owned tokens in `/tmp/mdm-owned.txt` (one per line).
- `sudo -v` must work — a non-admin account stops here.

## 5. Age key (this machine's own item)

```sh
mkdir -p ~/.age
op read 'op://Private/AGE Key MMDOT_<machine>/AGE/private key' > ~/.age/key.txt
chmod 600 ~/.age/key.txt
# verify against the grafana recipient pinned in mmdot.yml:
age-keygen -y ~/.age/key.txt   # must print age1pq5slc...
```

Confirm the exact 1Password item name here (pattern `AGE Key MMDOT_<machine>`;
personal's is `AGE Key MMDOT_MBP_PERSONAL`). Never use the personal item.

## 6. Cask ownership transfer

```sh
brew list --cask | sort > ~/code/repos/dotfiles/.hive-grafana-casks-before.txt  # baseline
mise bootstrap packages status \
  | awk '$1=="brew-cask" && $NF=="missing" {print $2}' | sort > /tmp/declared.txt
comm -12 <(brew list --cask | sort) /tmp/declared.txt > /tmp/transfer-all.txt
{ echo tailscale-app; cat /tmp/mdm-owned.txt 2>/dev/null; } | sort -u > /tmp/exclude.txt
comm -23 /tmp/transfer-all.txt /tmp/exclude.txt > /tmp/transfer.txt
test -s /tmp/transfer.txt                  # empty = parse failed, STOP
grep -x tailscale-app /tmp/transfer.txt    # must print nothing
cat /tmp/transfer.txt                      # EYEBALL before uninstalling
cp /tmp/transfer.txt ~/code/repos/dotfiles/cask-transfer-$(date +%Y%m%d).txt
xargs brew uninstall --cask < /tmp/transfer.txt   # answer sudo prompts
```

Notes from the personal run: some uninstalls (zoom-style pkg casks) need
sudo — run this in a real terminal. App settings survive in `~/Library`.
**RECOVERY** if anything dies mid-transfer:
`xargs brew install --cask < cask-transfer-<date>.txt`.

## 7. First converge — with 1Password up

**Launch and unlock 1Password first** — the transfer swaps its bundle, and
if the old process exits, the SSH agent dies and `dotsync`'s git pull fails
(personal-machine lesson). Then:

```sh
dotsync      # installs transferred casks mise-owned; sudo prompts once for
             # mac scripts; Dock resets; step 10 runs mmdot @grafana
dotsync      # second run must be a clean no-op (plan: 0 pending)
```

`goland`/`tuple` are no longer declared — uninstall opportunistically.
Escape casks (`docker-desktop`, `gcloud-cli`) install via
`setup/brew-casks.sh` from `BREW_ESCAPE_CASKS` in `mise.grafana.toml`.

## 8. Tailscale, last

Only after everything else converged, and with a fallback connection at
hand (wired/hotspot) — it's connectivity-critical:

```sh
brew uninstall --cask tailscale-app   # skip if MDM-owned
dotsync                               # mise reinstalls it (sudo: pkg install)
# log back in / approve the system extension if prompted
# RECOVERY: brew install --cask tailscale-app
```
