#!/usr/bin/env bash
# Prints frontmatter values for .hive research and plan documents in one call.
# Repository is parsed from the origin URL instead of `gh repo view` so this
# works offline and without a network round trip.
set -euo pipefail

remote=$(git remote get-url origin 2>/dev/null || true)
repo=$(printf '%s' "$remote" | sed -E 's#\.git$##; s#^.*[:/]([^/]+/[^/]+)$#\1#')
[ -n "$repo" ] || repo=$(basename "$(git rev-parse --show-toplevel)")

branch=$(git branch --show-current)
pushed=no
if [ -n "$(git branch -r --contains HEAD 2>/dev/null)" ]; then
  pushed=yes
fi

cat <<EOF
date: $(date +%Y-%m-%d)
repository: $repo
branch: ${branch:-detached}
commit: $(git rev-parse --short HEAD)
commit_full: $(git rev-parse HEAD)
author: $(git config user.name)
pushed: $pushed
EOF
