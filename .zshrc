# ============================================================================
# ZSH Plugin
plugins=(
    zsh-autosuggestions
)

# Load environment variables from ~/.env.local if the file exists
if [[ -f "$HOME/.shell.env" ]]; then
    export $(grep -v '^#' "$HOME/.shell.env" | xargs)
fi

export PATH=$PATH:$DOTFILES_DIR/bin

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

mac_config() {
    export EDITOR=nvim
    # Set Lazygit Config Dir
    export XDG_CONFIG_HOME="$HOME/.config"
    # GPG Keys
    export GPG_TTY=$(tty)
    # Homebrew Path
    export PATH=/opt/homebrew/bin:$PATH
    # Go
    export PATH="$HOME/Go/bin:$PATH"
    # tmuxifier
    export PATH="$HOME/.tmuxifier/bin:$PATH"
    # repomgr
    export REPOMGR_CONFIG="$HOME/.config/repomgr/repomgr.toml"
    export DIRWATCH_CONFIG="$HOME/.config/dirwatch/dirwatch.toml"
    alias rpm="repomgr"
    # Auto Edit Dotfiles and Change Directories
    edf() {
        nvim --cmd "cd $DOTFILES_DIR"
    }
    # Activate mise
    eval "$(/opt/homebrew/bin/mise activate zsh)"
    # rtx was renamed to mise so this is a temporary alias
    alias rtx="mise"

    export DOCKER_HOST=unix:///var/run/docker.sock
    alias docker-shim="sudo ln -s ~/Library/Containers/com.docker.docker/Data/docker.raw.sock /var/run/docker.sock"
    alias lzd=lazydocker
    alias lg=lazygit

    ## Default Mailpit Args
    alias mockmail="mailpit --smtp-auth-accept-any --smtp-auth-allow-insecure"

    mize() {
      mise list | fzf | awk '{print $1 "@" $2}' | xargs mise use
    }
}

## MAC OS
if (( AM_MAC > 0)); then;
    mac_config;
fi

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
SAVEHIST=20000 # save up to 50,000 lines in history. oh-my-zsh default is 10,000

# Shortcut to making exicutable.
alias plusx="chmod +x"
alias vim="nvim"
alias v="nvim"
alias rl="source ~/.zshrc"

if which bat > /dev/null; then
    alias cat="bat"
    elif which batcat > /dev/null; then
    alias cat="batcat"
fi

if which exa > /dev/null; then
    alias l='exa --all'
    alias ls="exa --long --header --git --icons --all --group-directories-first"
    alias tree="exa --tree --level=3"
elif which eza > /dev/null; then
    alias l='eza --all'
    alias ls="eza --long --header --git --icons --all --group-directories-first"
    alias tree="eza --tree --level=3"
else
    alias ls='ls -lah'
    alias l="ls -lah"
fi

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

alias cz="cd \$(fd --type directory | fzf)"

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
alias gbc="git branch | cut -c 3- | fzf | xargs git checkout"

eval "$(starship init zsh)"

# pnpm
export PNPM_HOME="/Users/hayden/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
export PATH="/opt/homebrew/sbin:$PATH"
