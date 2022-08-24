
xcode:
	sudo softwareupdate -i -a
	xcode-select --install || true

install-brew:
	curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash

osx-setup: xcode
	which brew || install-brew

	defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false

init:
	chmod +x ~/.dotfiles/bin/*