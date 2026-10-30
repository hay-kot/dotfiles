#!/usr/bin/env bash
# Sends a push notification to the user through ntfy, titled "<repo>: <Status>"
# and signed with a short name for the work, such as "Recipe Import Rewrite".
#
# Usage: push.sh [-a file] done|blocked|failed|update signature message...
#
# NTFY_AGENTS_URL is the full topic URL and NTFY_AGENTS_TOKEN an ntfy access
# token. Both come from personal_env_secrets, which mmdot renders into
# secrets/.env.local. Agents launched outside an interactive zsh never see the
# .zshrc exports, so the file is read directly when the environment lacks them.
set -euo pipefail

usage() {
  echo "usage: push.sh [-a file] done|blocked|failed|update signature message..." >&2
  exit 2
}

# -P resolves the ~/.claude/skills symlinks so ../ walks the real repo tree.
secrets_file="$(cd -P "$(dirname "$0")/../../../.." && pwd)/secrets/.env.local"

secret() {
  local name=$1 value=${!1:-}
  if [ -z "$value" ] && [ -r "$secrets_file" ]; then
    value=$(sed -n "s/^${name}=//p" "$secrets_file" | tail -n 1)
  fi
  if [ -z "$value" ]; then
    echo "push: $name is not set in the environment or $secrets_file" >&2
    return 1
  fi
  printf '%s' "$value"
}

# The origin remote names the repository even in clones whose directory
# names do not, such as hive session checkouts.
repo_name() {
  local remote
  remote=$(git remote get-url origin 2>/dev/null || true)
  if [ -n "$remote" ]; then
    printf '%s' "$remote" | sed -E 's#\.git$##; s#^.*[:/]##'
  else
    basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  fi
}

attachment=
while getopts "a:h" opt; do
  case $opt in
    a) attachment=$OPTARG ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

case ${1:-} in
  done) status=Done priority=default ;;
  blocked) status=Blocked priority=high ;;
  failed) status=Failed priority=high ;;
  update) status=Update priority=low ;;
  *) usage ;;
esac
signature=${2:-}
shift 2 || usage
[ -n "$signature" ] && [ $# -gt 0 ] || usage

body=$(printf '%s\n\n- %s' "$*" "$signature")
payload=(--data-binary "$body")
if [ -n "$attachment" ]; then
  if [ ! -r "$attachment" ]; then
    echo "push: cannot read $attachment" >&2
    exit 1
  fi
  # The file takes the request body, so the text moves to the query string;
  # a Message header cannot carry the newlines before the signature.
  payload=(-T "$attachment" -H "Filename: $(basename "$attachment")" --url-query "message=$body")
fi

url=$(secret NTFY_AGENTS_URL)
token=$(secret NTFY_AGENTS_TOKEN)

# The auth header goes through a file descriptor so the token stays out of
# curl's argv, where any process listing would show it.
if ! response=$(curl -sS --fail-with-body --max-time 15 \
  -H @<(printf 'Authorization: Bearer %s\n' "$token") \
  -H "Title: $(repo_name): $status" \
  -H "Priority: $priority" \
  "${payload[@]}" \
  "$url"); then
  echo "push: ntfy rejected the message: $response" >&2
  exit 1
fi

echo "push: sent"
