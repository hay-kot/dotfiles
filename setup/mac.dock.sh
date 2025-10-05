#!/bin/bash

# Ask for the administrator password upfront
echo "apple: need administrator rights for macOS configuration"
sudo -v

###############################################################################
# Dock                                                                        #
###############################################################################

# Set the icon size of Dock items to 72 pixels
defaults write com.apple.dock tilesize -int 52

#"Setting Dock to auto-hide and removing the auto-hiding delay"
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0

# Keep-alive: update existing `sudo` time stamp until `.macos` has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Define the list of applications to add to the Dock
apps_to_add=(
  "/Applications/Brave Browser.app"
  "/Applications/Wezterm.app"
  "/Applications/Signal.app"
  "/Applications/Obsidian.app"
)

# Function to refresh the Dock
refresh_dock() {
  echo "Refreshing the Dock..."
  killall Dock
}

# Function to clear the Dock
clear_dock() {
  echo "Removing all existing items from the Dock..."
  defaults write com.apple.dock persistent-apps -array
  defaults write com.apple.dock persistent-others -array
}

# Function to add apps to the Dock
add_apps_to_dock() {
  echo "Adding specified applications to the Dock..."
  for app in "${apps_to_add[@]}"; do
    if [[ -d "$app" ]]; then
      defaults write com.apple.dock persistent-apps -array-add \
        "<dict>
           <key>tile-data</key>
           <dict>
             <key>file-data</key>
             <dict>
               <key>_CFURLString</key>
               <string>$app</string>
               <key>_CFURLStringType</key>
               <integer>0</integer>
             </dict>
           </dict>
         </dict>"
      echo "Added $app to the Dock."
    else
      echo "Application not found: $app"
    fi
  done
}

# Execute the functions
clear_dock
add_apps_to_dock
refresh_dock

echo "Dock customization complete!"
