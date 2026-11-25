#!/bin/bash
# Usage: link-skill.sh <skill-dir> <name>
# Links a skill directory into .claude/skills/<name> of the current checkout
# and hides it from git through .git/info/exclude, so a repo gets a personal
# skill without a committed file. Run as a hive rule command.
#
# A missing skill only warns: an optional skill must not fail session creation.

set -euo pipefail

src="${1:?usage: link-skill.sh <skill-dir> <name>}"
name="${2:?usage: link-skill.sh <skill-dir> <name>}"

if [ ! -f "$src/SKILL.md" ]; then
    echo "link-skill: no SKILL.md in $src; skipping $name" >&2
    exit 0
fi

top="$(cd "$(git rev-parse --show-toplevel)" && pwd -P)"
mkdir -p .claude/skills
# .claude/skills can be a symlink into a tracked directory (.agents/skills),
# so exclude the path git sees, not the path the link goes through.
skills="$(cd .claude/skills && pwd -P)"
case "$skills" in
    "$top"/*) rel="${skills#"$top"/}/$name" ;;
    *) rel="" ;;
esac

dest=".claude/skills/$name"
if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "link-skill: $dest exists and is not a link; leaving it" >&2
    exit 0
fi
ln -sfn "$src" "$dest"

if [ -n "$rel" ]; then
    exclude="$(git rev-parse --git-path info/exclude)"
    mkdir -p "$(dirname "$exclude")"
    touch "$exclude"
    grep -qxF "/$rel" "$exclude" || echo "/$rel" >> "$exclude"
fi
