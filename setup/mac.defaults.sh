#!/usr/bin/env bash
set -euo pipefail

# Set Zed as the default for common text and config file types.
# Uses infat: https://github.com/philocalyst/infat

infat set Zed --type plain-text

# Extensions without a UTI binding fail with Launch Services error -50;
# tolerated per-extension (the old script silently masked every failure).
# html is deliberately absent: binding public.html prompts to change the
# default browser.
for ext in json yaml yml toml xml csv env md txt log css js ts sh; do
  infat set Zed --ext "$ext" 2>/dev/null || echo "defaults: .$ext association skipped (LS error -50)"
done

echo "defaults: done!"
