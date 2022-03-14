###############################################################################
#                     Mac OS Configuration Functions                          #
###############################################################################

AM_MAC=0

is_mac() {
  if [[ $OSTYPE == 'darwin'* ]]; then
        AM_MAC=1
  fi
}

is_mac

mac_config() {
    #### FIG ENV VARIABLES ####
    # Please make sure this block is at the start of this file.
    [ -s ~/.fig/shell/pre.sh ] && source ~/.fig/shell/pre.sh
    #### END FIG ENV VARIABLES ####

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
    export NVM_DIR="$HOME/.nvm"
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
    [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

    # ============================================================================
    # Go Setup Functions 
    export PATH="$HOME/Go/bin:$PATH"

    #### FIG ENV VARIABLES ####
    # Please make sure this block is at the end of this file.
    [ -s ~/.fig/fig.sh ] && source ~/.fig/fig.sh
    #### END FIG ENV VARIABLES ####
}


if (( AM_MAC > 0)); then; mac_config; fi

export TERM="xterm-256color"
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes


# ZSH_THEME="agnoster"
export DEFAULT_USER="$(whoami)"
DISABLE_AUTO_TITLE="true"


# ============================================================================
# ZSH Plugin
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    git
    zsh-completions
    zsh-autosuggestions
    history-substring-search
    docker
    pyenv
    systemd
    )

source $ZSH/oh-my-zsh.sh

## MAC OS

if (( AM_MAC > 0)); then
  source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

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

export PATH=$PATH:~/.quickzsh/todo/bin    #usig alias doesn't properly work

autoload -U compinit && compinit

# export COOKIECUTTER_CONFIG="$HOME/linux-dev/dotfiles/cookiecutter.yaml"

SAVEHIST=10000    #save upto 50,000 lines in history. oh-my-zsh default is 10,000
#setopt hist_ignore_all_dups     # dont record duplicated entries in history during a single session

# Start stuff that downloads in ~/Downloads
alias wget="cd ~/Downloads; wget"

# Shortcut to making exicutable.
alias plusx="chmod +x"


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
}

# Only Alias apt-get if we are on linux
if ! [ AM_MAC==1 ]; then; linux_aliases; fi





# Stuff That Came With Template
alias myip="wget -qO- https://wtfismyip.com/text"	# quickly show external ip address
alias l="ls -lah"
alias x="exit"
alias k="k -h"						# show human readable filesizes, in kb, mb etc

repos() {
    # Navigate to repos director and open target directory is specified
    if [ -z "$1" ]; then
        cd ~/code/repos && ls -la
        return
    fi

    cd ~/code/repos/$1
}

git-big() {
    if [ -z "$1" ]; then
        echo "Usage: git-big <number of files>"
        return
    fi

    git rev-list --objects --all \
    | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' \
    | sed -n 's/^blob //p' \
    | sort --numeric-sort --key=2 \
    | tail -n $1 \
    | cut -c 1-12,41- \
    | $(command -v gnumfmt || echo numfmt) --field=2 --to=iec-i --suffix=B --padding=7 --round=nearest
}
 
###############################################################################
#                         Alias Functions                                     #
###############################################################################

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

# Opens Last lf Directory in VSCode
lfcode () {
    tmp="$(mktemp)"
    lf -last-dir-path="$tmp" "$@"
    if [ -f "$tmp" ]; then
        dir="$(cat "$tmp")"
        rm -f "$tmp"
        [ -d "$dir" ] && [ "$dir" != "$(pwd)" ] && code "$dir"
    fi
}
bindkey -s '^[c' 'lfcode\n'


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
function mkcd {
  if [ ! -n "$1" ]; then
    echo "Enter a directory name"
  elif [ -d $1 ]; then
    echo "\`$1' already exists"
  else
    mkdir $1 && cd $1
  fi
}

###############################################################################
#                                  Prompt                                     #
###############################################################################

eval "$(oh-my-posh --init --shell zsh --config ~/.posh-themes/tonybaloney.omp.json)"

# New Line Prompt
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
      print -n "%{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
      print -n "%{%k%}"
  fi

  print -n "%{%f%}"
  CURRENT_BG='' 

  #Adds the new line and ➜ as the start character.
  printf "\n ➜";
}


