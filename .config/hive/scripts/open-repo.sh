#!/bin/bash
# Usage: open-repo.sh <repo-path>
# Opens a repository's web page in the default browser.
# Converts the origin remote (SSH or HTTPS) to an https:// web URL.
# Works for github, gitea, and generic ssh remotes.

set -euo pipefail

REPO_PATH="${1:-.}"

# Resolve a remote URL, preferring origin and falling back to the first remote.
url="$(git -C "$REPO_PATH" remote get-url origin 2>/dev/null || true)"
if [ -z "$url" ]; then
    first_remote="$(git -C "$REPO_PATH" remote 2>/dev/null | head -n1)"
    if [ -n "$first_remote" ]; then
        url="$(git -C "$REPO_PATH" remote get-url "$first_remote" 2>/dev/null || true)"
    fi
fi

if [ -z "$url" ]; then
    echo "Error: no git remote found in $REPO_PATH" >&2
    exit 1
fi

# Strip a trailing .git if present.
url="${url%.git}"

case "$url" in
    ssh://*)
        # ssh://[user@]host[:port]/owner/repo -> https://host/owner/repo
        rest="${url#ssh://}"
        rest="${rest#*@}"
        hostport="${rest%%/*}"
        repo_path="${rest#*/}"
        host="${hostport%%:*}"
        web="https://${host}/${repo_path}"
        ;;
    http://*|https://*)
        web="$url"
        ;;
    *:*)
        # scp-like: [user@]host:owner/repo -> https://host/owner/repo
        # user may be git, gitea, forgejo, etc. and is optional.
        host_path="${url#*@}"
        host="${host_path%%:*}"
        repo_path="${host_path#*:}"
        web="https://${host}/${repo_path}"
        ;;
    *)
        echo "Error: unsupported remote url: $url" >&2
        exit 1
        ;;
esac

open "$web"
