#!/bin/bash
# Provision Grafana Agent observability for the coding agents.
#
# Renders ~/.config/agento11y/config.env from the 1Password item named by
# AGENTO11Y_OP_ITEM, then registers the Claude Code plugin and the pi extension.
# The plugins are what capture a session; agents are launched normally, so
# nothing wraps or shadows `claude` and `pi`.
#
# 1Password stays the source of truth and this file is the rendered copy --
# the same pattern as the age identity at ~/.age/key.txt.
#
# Never fails the bootstrap. Without a readable item the agents still run; the
# plugin finds no credentials and does nothing.

set -uo pipefail

if ! command -v agento11y >/dev/null 2>&1; then
  echo "agento11y: not installed, skipping"
  exit 0
fi

# env.<machine>.sh has already written ~/.shell.env by this point.
if [ -r "$HOME/.shell.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$HOME/.shell.env" 2>/dev/null || true
  set +a
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agento11y"
CONFIG_FILE="$CONFIG_DIR/config.env"

render_config() {
  [ -n "${AGENTO11Y_OP_ITEM:-}" ] || { echo "agento11y: AGENTO11Y_OP_ITEM not set"; return 1; }
  command -v op >/dev/null 2>&1 || { echo "agento11y: 1Password CLI not installed"; return 1; }
  command -v jq >/dev/null 2>&1 || { echo "agento11y: jq not installed"; return 1; }

  # AGENTO11Y_OP_ITEM is "<vault>/<item>".
  local vault="${AGENTO11Y_OP_ITEM%%/*}" item="${AGENTO11Y_OP_ITEM#*/}"
  [ -n "$vault" ] && [ "$vault" != "$AGENTO11Y_OP_ITEM" ] || {
    echo "agento11y: AGENTO11Y_OP_ITEM must be <vault>/<item>, got '$AGENTO11Y_OP_ITEM'"; return 1; }

  local json
  json="$(op item get "$item" --vault "$vault" --format json 2>/dev/null </dev/null)" || json=""
  [ -n "$json" ] || { echo "agento11y: cannot read 1Password item '$AGENTO11Y_OP_ITEM'"; return 1; }

  local endpoint tenant token otlp
  IFS=$'\t' read -r endpoint tenant token otlp < <(printf '%s' "$json" | jq -r '
    def field($n): (first(.fields[]? | select(.label == $n) | .value) // "");
    [ field("endpoint"), field("tenant_id"), field("credential"), field("otlp_endpoint") ] | @tsv
  ' 2>/dev/null) || true

  [ -n "${endpoint:-}" ] && [ -n "${tenant:-}" ] && [ -n "${token:-}" ] || {
    echo "agento11y: item '$AGENTO11Y_OP_ITEM' lacks endpoint/tenant_id/credential"; return 1; }

  mkdir -p "$CONFIG_DIR" || return 1

  # Create the file empty at 0600 before the token goes in, so it is never
  # briefly world-readable.
  local tmp
  tmp="$(mktemp "$CONFIG_DIR/.config.env.XXXXXX")" || return 1
  chmod 600 "$tmp"
  {
    echo "# Rendered by setup/agento11y.sh from 1Password ($AGENTO11Y_OP_ITEM)."
    echo "# Edit the 1Password item, not this file: dotsync overwrites it."
    echo "AGENTO11Y_ENDPOINT=$endpoint"
    echo "AGENTO11Y_AUTH_TENANT_ID=$tenant"
    echo "AGENTO11Y_AUTH_TOKEN=$token"
    [ -n "${otlp:-}" ] && echo "AGENTO11Y_OTEL_EXPORTER_OTLP_ENDPOINT=$otlp"
    echo "AGENTO11Y_CONTENT_CAPTURE_MODE=${AGENTO11Y_CONTENT_CAPTURE_MODE:-full}"
    echo "AGENTO11Y_AUTO_CODING_AGENT_TAGS=true"
    echo "AGENTO11Y_AUTO_CODING_AGENT_TAGS_NAMES=user,repo"
    [ -n "${AGENTO11Y_TAGS:-}" ] && echo "AGENTO11Y_TAGS=$AGENTO11Y_TAGS"
  } >>"$tmp" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$CONFIG_FILE" || { rm -f "$tmp"; return 1; }
  echo "agento11y: rendered $CONFIG_FILE from 1Password"
}

if ! render_config; then
  echo "agento11y: sessions are not being recorded (agents run normally)"
fi

# Registering here means a fresh machine is wired before the first session.
# Both targets are symlinked into this repo, so the versions stay tracked.
for agent in claude pi; do
  command -v "$agent" >/dev/null 2>&1 || continue
  if agento11y "$agent" install --json >/dev/null 2>&1; then
    echo "agento11y: registered the $agent plugin"
  else
    echo "agento11y: could not register the $agent plugin"
  fi
done

exit 0
