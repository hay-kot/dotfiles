#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Zen + Hive Split
# @raycast.description Zen left, Hive right on the main screen; press again to swap between 36/64 and 60/40
# @raycast.packageName Windows
# @raycast.mode silent

exec "$HOME/.local/bin/winctl" split app.zen-browser.zen com.hivedesktop.app 0.36,0.6 2>&1
