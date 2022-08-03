# Fig pre block. Keep at the top of this file.
[[ -f "$HOME/.fig/shell/zshrc.pre.zsh" ]] && . "$HOME/.fig/shell/zshrc.pre.zsh"
# ============================================================================
# ZSH Plugin
plugins=(
    zsh-autosuggestions
)

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh
source $ZSH/oh-my-zsh.sh


AM_MAC=0

is_mac() {
    if [[ $OSTYPE == 'darwin'* ]]; then
        AM_MAC=1
    fi
}

is_mac

## MAC OS
if (( AM_MAC > 0)); then;
    # Fig pre block. Keep at the top of this file.
fi

mac_config() {
    # ============================================================================
    # Homebrew Path
    export PATH=/opt/homebrew/bin:$PATH
    
    # ============================================================================
    # Python Setup Functions
    
    # Pyenv
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    
    # Poetry
    export PATH="/opt/homebrew/opt/node@14/bin:$PATH"
    
    # ============================================================================
    # Node Setup Functions
    export NVM_DIR=~/.nvm
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" --no-use # This loads nvm
    alias node='unalias node ; unalias npm ; nvm use default ; node $@'
    alias npm='unalias node ; unalias npm ; nvm use default ; npm $@'
    
    # ============================================================================
    # Go Setup Functions
    export PATH="$HOME/Go/bin:$PATH"
    
    # General Aliases
    alias ls='exa'
    alias l="exa --long --header --git --icons"
}

## MAC OS
if (( AM_MAC > 0)); then;
    mac_config;
fi

export TERM="xterm-256color"
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH



# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes


# ZSH_THEME="agnoster"
export DEFAULT_USER="$(whoami)"
DISABLE_AUTO_TITLE="true"




# ============================================================================
# Python Dev Common
POETRY_VIRTUALENVS_IN_PROJECT=true
alias activate="source ./.venv/bin/activate"
export PATH="$HOME/.poetry/bin:$PATH"
export PATH=$PATH:~/.local/bin

export PATH="$HOME/scripts:$PATH"

NPM_PACKAGES="${HOME}/.npm"
PATH="$NPM_PACKAGES/bin:$PATH"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPS="--extended"

export MARKER_KEY_NEXT_PLACEHOLDER="\C-b"   #change maker key binding from Ctr+t to Ctr+b

[[ -s "$HOME/.local/share/marker/marker.sh" ]] && source "$HOME/.local/share/marker/marker.sh"

export PATH=$PATH:~/.quickzsh/todo/bin    # using alias doesn't properly work

autoload -U compinit && compinit
SAVEHIST=10000    #save upto 50,000 lines in history. oh-my-zsh default is 10,000

# Start stuff that downloads in ~/Downloads
alias wget="cd ~/Downloads; wget"

# Shortcut to making exicutable.
alias plusx="chmod +x"
alias vim="nvim"
alias rl="source ~/.zshrc"
alias cat="bat"

linux_aliases() {
    # Custom Apt
    alias app="sudo apt-get"
    alias app-remove="sudo apt-get remove"
    alias app-install="sudo apt-get install"
    alias app-edit="sudo envedit /etc/apt/sources.list"
    alias app-search="apt-cache --names-only search"
    alias app-search-all="apt-cache search"
    alias app-update="sudo apt-get update && sudo apt-get upgrade"
    alias app-info="apt-cache showpkg"
    
    alias l="ls -lah"
}

# Only Alias apt-get if we are on linux
if (( AM_MAC == 0 )); then; linux_aliases; fi

# Stuff That Came With Template
alias myip="wget -qO- https://wtfismyip.com/text"	# quickly show external ip address
alias x="exit"
alias k="k -h"						# show human readable filesizes, in kb, mb etc

###############################################################################
#                         Alias Functions                                     #
###############################################################################

alias fcode="code \`gofind find repos\`"

repos() {
    # Navigate to repos director and open target directory is specified
    if [ -z "$1" ]; then
        cd "`gofind find repos`"
        return
    fi
    
    cd ~/code/repos/$1
}

init() {
    # Go Installs
    go install github.com/hay-kot/gofind@latest
    
    # Make Scripts Executable
    chmod +x ~/scripts/*
    
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

speedtest() {
    curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -
}

# Find geo info from IP
ipgeo() {
    # Specify ip or your ip will be used
    if [ "$1" ]; then
        curl "http://api.db-ip.com/v2/free/$1"
    else
        curl "http://api.db-ip.com/v2/free/$(myip)"
    fi
}

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

### Prompt ###
eval "$(oh-my-posh --init --shell zsh --config ~/.posh-themes/tonybaloney.omp.json)"

## MAC OS
if (( AM_MAC > 0)); then;
    # Fig post block. Keep at the bottom of this file.
fi

# fh - search in your command history and execute selected command
fh() {
    eval $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed 's/ *[0-9]* *//')
}

# Fig post block. Keep at the bottom of this file.
[[ -f "$HOME/.fig/shell/zshrc.post.zsh" ]] && . "$HOME/.fig/shell/zshrc.post.zsh"
