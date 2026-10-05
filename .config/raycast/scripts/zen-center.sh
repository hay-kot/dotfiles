#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Zen Center
# @raycast.description Show Zen in the middle two-thirds of the main screen; hide it if it is already in front
# @raycast.packageName Windows
# @raycast.mode silent

exec "$HOME/.local/bin/winctl" summon app.zen-browser.zen 1/6,0.03,2/3,0.94 2>&1
