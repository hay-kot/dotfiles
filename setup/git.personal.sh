#!/bin/bash

set -e

echo "git: set bw signing key"
git config --global gpg.format ssh
git config --global user.signingkey "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIItPXIuTYpgamCjUnv40GA4Oo5Aji5x86pGwm9tuH33T"
git config --global commit.gpgsign true
