xcode:
	sudo softwareupdate -i -a
	xcode-select --install || true

init:
	chmod +x ./ansible/git-init.sh
	cd ansible && ./git-init.sh
	chmod +x ./bin/*
	chmod +x ./setup/**/*.sh

playbook:
	./setup/run.sh .*
	ansible-playbook ansible/playbook.yml --vault-password-file ./secrets/.vaultpass --ask-become-pass

encrypt:
	ansible-vault encrypt --vault-password-file ./secrets/.vaultpass ./ansible/vars/vault.yml

decrypt:
	ansible-vault decrypt --vault-password-file ./secrets/.vaultpass ./ansible/vars/vault.yml

fmt/dotfiles:
	stylua --config-path=./.config/nvim/stylua.toml ./.config/nvim/
