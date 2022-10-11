# Fig pre block. Keep at the top of this file.
[[ -f "$HOME/.fig/shell/zshrc.pre.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.pre.zsh"
# ============================================================================
# ZSH Plugin
plugins=(
    zsh-autosuggestions
)

export PATH=$PATH:$HOME/.dotfiles/bin

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh
source $ZSH/oh-my-zsh.sh

export ENVAULT_FILE=~/.dotfiles/secrets/.env.local
export ENVAULT_CONFG=~/.dotfiles/secrets/genv-config.json

AM_MAC=0

is_mac() {
    if [[ $OSTYPE == 'darwin'* ]]; then
        AM_MAC=1
    fi
}

is_mac

mac_config() {
    # Homebrew Path
    export PATH=/opt/homebrew/bin:$PATH
    
    # Python
    # Pyenv
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    
    # Node
    export PATH="/opt/homebrew/opt/node@14/bin:$PATH"
    export NVM_DIR=~/.nvm
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" --no-use # This loads nvm
    alias node='unalias node ; unalias npm ; nvm use default ; node $@'
    alias npm='unalias node ; unalias npm ; nvm use default ; npm $@'
    
    # Go
    export PATH="$HOME/Go/bin:$PATH"
    
    export NOTEBOOK_LOC="~/code/notebook"
}

## MAC OS
if (( AM_MAC > 0)); then;
    mac_config;
fi

export TERM="xterm-256color"
export DEFAULT_USER="$(whoami)"
DISABLE_AUTO_TITLE="true"

# ============================================================================
# Python Dev Common
POETRY_VIRTUALENVS_IN_PROJECT=true
alias activate="source ./.venv/bin/activate"
export PATH="$HOME/.poetry/bin:$PATH"
export PATH=$PATH:~/.local/bin

NPM_PACKAGES="${HOME}/.npm"
PATH="$NPM_PACKAGES/bin:$PATH"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPS="--extended"

export MARKER_KEY_NEXT_PLACEHOLDER="\C-b"   # change maker key binding from Ctr+t to Ctr+b

[[ -s "$HOME/.local/share/marker/marker.sh" ]] && source "$HOME/.local/share/marker/marker.sh"

export PATH=$PATH:~/.quickzsh/todo/bin    # using alias doesn't properly work

autoload -U compinit && compinit
SAVEHIST=10000 # save up to 50,000 lines in history. oh-my-zsh default is 10,000

# Shortcut to making exicutable.
alias plusx="chmod +x"
alias vim="nvim"
alias rl="source ~/.zshrc"

if which bat > /dev/null; then
    alias cat="bat"
    elif which batcat > /dev/null; then
    alias cat="batcat"
fi

if which exa > /dev/null; then
    alias ls='exa --all'
    alias l="exa --long --header --git --icons --all"
else
    alias ls='ls -lah'
    alias l="ls -lah"
fi

# Only Alias apt-get if we are on linux
if (( AM_MAC == 0 )); then; linux_aliases; fi

# Stuff That Came With Template
alias myip="wget -qO- https://wtfismyip.com/text"	# quickly show external ip address
alias x="exit"
alias k="k -h"						# show human readable filesizes, in kb, mb etc

###############################################################################
#                         Alias Functions                                     #
###############################################################################

repos() {
    # Navigate to repos director and open target directory is specified
    if [ -z "$1" ]; then
        cd "`gofind find repos`"
        return
    fi
    
    cd ~/code/repos/$1
}

# Use lf to switch directories and bind it to ctrl-o
lfcd () {
    tmp="$(mktemp)"
    lf -last-dir-path="$tmp" "$@"
    if [ -f "$tmp" ]; then
        dir="$(cat "$tmp")"
        rm -f "$tmp"
        [ -d "$dir" ] && [ "$dir" != "$(pwd)" ] && cd "$dir"
    fi
}
bindkey -s '^o' 'lfcd\n'

# Make and CD into directory
mkcd() {
    if [ ! -n "$1" ]; then
        echo "Enter a directory name"
        elif [ -d $1 ]; then
        echo "\`$1' already exists"
    else
        mkdir $1 && cd $1
    fi
}

killport() {
    kill $(lsof -t -i:$1)
}

# fh - search in your command history and execute selected command
fh() {
    eval $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed 's/ *[0-9]* *//')
}

# Magic .env file loading function
if [ -f ~/.dotfiles/secrets/.env.local ]; then
    if [[ -s ~/.dotfiles/secrets/.env.local ]]; then
        export $(cat ~/.dotfiles/secrets/.env.local | xargs)
    fi
else
    mkdir -p ~/.dotfiles/secrets
    touch ~/.dotfiles/secrets/.env.local
fi

alias rgnb="rg -- "

# Gum Aliases
alias branch-delete="git branch | cut -c 3- | gum choose --no-limit | xargs git branch -D"
alias checkout-pr="gh pr list | cut -f1,2 | gum choose | cut -f1 | xargs gh pr checkout"

### Prompt ###
# eval "$(oh-my-posh --init --shell zsh --config ~/.posh-themes/tonybaloney.omp.json)"
eval "$(starship init zsh)"

# Fig post block. Keep at the bottom of this file.
[[ -f "$HOME/.fig/shell/zshrc.post.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.post.zsh"
