#!/bin/bash
set -e
REPO_DIR="$HOME/code/Repos"
mkdir -p "$REPO_DIR"
REPO_NAME=$(basename "git@github.com:colonyops/diff-review.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:colonyops/diff-review.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:colonyops/hive.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:colonyops/hive.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/criterio.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/criterio.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/dirwatch.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/dirwatch.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/easyemails.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/easyemails.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/flint.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/flint.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/gobusgen.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/gobusgen.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/gofind.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/gofind.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/haykot.dev.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/haykot.dev.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/httpkit.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/httpkit.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/local-review.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/local-review.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/mdparse.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/mdparse.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/mmdot.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/mmdot.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/obsidian-dnd-ui-toolkit.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/obsidian-dnd-ui-toolkit.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/plugs.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/plugs.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/pres-bubble-tea-tuis.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/pres-bubble-tea-tuis.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/pres-building-a-saas-stack-in-go.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/pres-building-a-saas-stack-in-go.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/recipes-api.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/recipes-api.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/recipinned.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/recipinned.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/scaffold.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/scaffold.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/scaffold-go-cli.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/scaffold-go-cli.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/scaffold-go-pkg.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/scaffold-go-pkg.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:hay-kot/scaffold-go-web.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:hay-kot/scaffold-go-web.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:mealie-recipes/discord-bot.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:mealie-recipes/discord-bot.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:mealie-recipes/mealie.io.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:mealie-recipes/mealie.io.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:mealie-recipes/recipes-server.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:mealie-recipes/recipes-server.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "git@github.com:mealie-recipes/mealie.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "git@github.com:mealie-recipes/mealie.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "ssh://gitea@gitea.kotel.app:222/renovate/renovate-v2.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "ssh://gitea@gitea.kotel.app:222/renovate/renovate-v2.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "ssh://gitea@gitea.kotel.app:222/hay-kot/coros.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "ssh://gitea@gitea.kotel.app:222/hay-kot/coros.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "ssh://gitea@gitea.kotel.app:222/hay-kot/infra.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "ssh://gitea@gitea.kotel.app:222/hay-kot/infra.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi
REPO_NAME=$(basename "ssh://gitea@gitea.kotel.app:222/hay-kot/training-assistant.git" .git)
if [ ! -d "$REPO_DIR/$REPO_NAME" ]; then
  echo "Cloning $REPO_NAME..."
  git clone "ssh://gitea@gitea.kotel.app:222/hay-kot/training-assistant.git" "$REPO_DIR/$REPO_NAME"
else
  echo "Skipping $REPO_NAME (already exists)"
fi