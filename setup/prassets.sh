#!/bin/bash
# Copies the R2 key that pra (github.com/hay-kot/prassets) uploads PR assets
# with from the 1Password item named by PRASSETS_OP_ITEM into the login
# keychain (service pra-agent-assets, accounts access_key and secret_key).
# .config/prassets/config.yaml reads it back with `security`, so the key is
# never a plaintext file and pra keeps working while 1Password is locked
# (agents run overnight).
#
# 1Password stays the source of truth and the keychain holds the copy; every
# dotsync refreshes it.
#
# Never fails the bootstrap. Without a readable item pra has no key and
# `pra config check` says so.

set -uo pipefail

# env.<machine>.sh has already written ~/.shell.env by this point.
if [ -r "$HOME/.shell.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$HOME/.shell.env" 2>/dev/null || true
  set +a
fi

SERVICE="pra-agent-assets"

# security -i reads the command from stdin, which keeps the key out of the
# process list. Its parser splits on spaces and quotes, so only plain tokens
# are accepted (R2 keys are hex).
store_key() {
  local account="$1" value="$2"
  [[ "$value" =~ ^[A-Za-z0-9]+$ ]] || { echo "prassets: $account is not alphanumeric"; return 1; }
  # Delete and re-add rather than add -U: changing the access list of an
  # existing item asks for confirmation in a dialog. -T lets
  # /usr/bin/security read the new item without one.
  security delete-generic-password -s "$SERVICE" -a "$account" >/dev/null 2>&1 || true
  printf 'add-generic-password -s %s -a %s -T /usr/bin/security -w %s\n' \
    "$SERVICE" "$account" "$value" | security -i >/dev/null || return 1
}

store_credentials() {
  [ -n "${PRASSETS_OP_ITEM:-}" ] || { echo "prassets: PRASSETS_OP_ITEM not set"; return 1; }
  command -v security >/dev/null 2>&1 || { echo "prassets: no macOS keychain (security)"; return 1; }
  command -v op >/dev/null 2>&1 || { echo "prassets: 1Password CLI not installed"; return 1; }
  command -v jq >/dev/null 2>&1 || { echo "prassets: jq not installed"; return 1; }

  # PRASSETS_OP_ITEM is "<vault>/<item>".
  local vault="${PRASSETS_OP_ITEM%%/*}" item="${PRASSETS_OP_ITEM#*/}"
  [ -n "$vault" ] && [ "$vault" != "$PRASSETS_OP_ITEM" ] || {
    echo "prassets: PRASSETS_OP_ITEM must be <vault>/<item>, got '$PRASSETS_OP_ITEM'"; return 1; }

  local json
  json="$(op item get "$item" --vault "$vault" --format json 2>/dev/null </dev/null)" || json=""
  [ -n "$json" ] || { echo "prassets: cannot read 1Password item '$PRASSETS_OP_ITEM'"; return 1; }

  local access_key secret_key
  IFS=$'\t' read -r access_key secret_key < <(printf '%s' "$json" | jq -r '
    def field($n): (first(.fields[]? | select(.label == $n) | .value) // "");
    [ field("access_key_id"), field("secret_access_key") ] | @tsv
  ' 2>/dev/null) || true

  [ -n "${access_key:-}" ] && [ -n "${secret_key:-}" ] || {
    echo "prassets: item '$PRASSETS_OP_ITEM' lacks access_key_id/secret_access_key"; return 1; }

  store_key access_key "$access_key" || return 1
  store_key secret_key "$secret_key" || return 1
  echo "prassets: stored the R2 key in the login keychain ($SERVICE)"
}

if ! store_credentials; then
  echo "prassets: pra has no key (agents cannot upload PR assets)"
fi

exit 0
