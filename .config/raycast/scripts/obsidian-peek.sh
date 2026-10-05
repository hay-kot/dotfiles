#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Obsidian Peek
# @raycast.description Show Obsidian centered on the main screen; hide it if it is already in front
# @raycast.packageName Windows
# @raycast.mode silent

exec "$HOME/.local/bin/winctl" summon md.obsidian 0.225,0.03,0.55,0.94 2>&1
