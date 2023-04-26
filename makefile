xcode:
	sudo softwareupdate -i -a
	xcode-select --install || true

install-brew:
	curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash

osx-setup: xcode
	which brew || install-brew

	defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false

init:
	chmod +x ~/.dotfiles/ansible/git-init.sh
	cd ansible && ./git-init.sh
	chmod +x ~/.dotfiles/bin/*

playbook:
	ansible-playbook ansible/playbook.yml --vault-password-file ./secrets/.vaultpass --ask-become-pass

encrypt:
	ansible-vault encrypt --vault-password-file ./secrets/.vaultpass ./ansible/vars/vault.yml

decrypt:
	ansible-vault decrypt --vault-password-file ./secrets/.vaultpass ./ansible/vars/vault.yml

fmt/dotfiles:
	stylua ./.config/nvim/
