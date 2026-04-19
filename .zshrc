# ============================================================================
# Auto Init Plugin Manager
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

zinit light zsh-users/zsh-syntax-highlighting # syntax highlighting
zinit light zsh-users/zsh-completions         # completions
zinit light zsh-users/zsh-autosuggestions     # auto-suggest history
zinit light Aloxaf/fzf-tab                    # fzf tab completion

# End ========================================================================

fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
  zcompile ${ZDOTDIR:-$HOME}/.zcompdump
else
  compinit -C
fi

zinit cdreplay -q

# up / down arrow history-search
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '→' autosuggest-accept

# For zsh with zsh-autosuggestions
HISTSIZE=20000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups

# Dedupe PATH entries across all prepends/appends below
typeset -U path PATH

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':completion:*:*:make:*' tag-order 'targets'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'

# Load environment variables from ~/.env.local if the file exists
if [[ -f "$HOME/.shell.env" ]]; then
    set -a
    source "$HOME/.shell.env"
    set +a
fi

# Set $DOTFILES_DIR to ~/.dotfiles if not already set
if [[ -z "$DOTFILES_DIR" ]]; then
    export DOTFILES_DIR="$HOME/.dotfiles"
fi

export PATH=$PATH:$DOTFILES_DIR/bin

AM_MAC=0

is_mac() {
    if [[ $OSTYPE == 'darwin'* ]]; then
        AM_MAC=1
    fi
}

is_mac

edf() {
    nvim --cmd "cd $DOTFILES_DIR"
}

mac_config() {
    export EDITOR=nvim
    export XDG_CONFIG_HOME="$HOME/.config"
    export GPG_TTY=$(tty)
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/opt/homebrew/opt/libpq/bin:$PATH"
    export PATH="$HOME/Go/bin:$HOME/.tmuxifier/bin:$PATH"

    # pnpm
    export PNPM_HOME="$HOME/Library/pnpm"
    case ":$PATH:" in
      *":$PNPM_HOME:"*) ;;
      *) export PATH="$PNPM_HOME:$PATH" ;;
    esac

    eval "$(/opt/homebrew/bin/mise activate zsh)"
    export DOCKER_HOST=unix:///var/run/docker.sock
    alias docker-shim="sudo ln -s ~/Library/Containers/com.docker.docker/Data/docker.raw.sock /var/run/docker.sock"
    alias lzd=lazydocker
    alias lg=lazygit
    alias mockmail="mailpit --smtp-auth-accept-any --smtp-auth-allow-insecure"

    mize() {
      mise list | fzf | awk '{print $1 "@" $2}' | xargs mise use
    }
}

## MAC OS
if (( AM_MAC > 0)); then;
    mac_config;
fi

export DEFAULT_USER="$USER"
DISABLE_AUTO_TITLE="true"

POETRY_VIRTUALENVS_IN_PROJECT=true
alias activate="source ./.venv/bin/activate"

export PATH="$HOME/.poetry/bin:$HOME/.npm/bin:$HOME/.opencode/bin:$PATH"
export PATH="$PATH:$HOME/.local/bin"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh


# Theme https://github.com/folke/tokyonight.nvim/blob/main/extras/fzf/tokyonight_night.sh
export FZF_DEFAULT_OPTS="\
  --highlight-line \
  --info=inline-right \
  --ansi \
  --layout=reverse \
  --border=none \
  --color=bg+:#283457 \
  --color=bg:#16161e \
  --color=border:#27a1b9 \
  --color=fg:#c0caf5 \
  --color=gutter:#16161e \
  --color=header:#ff9e64 \
  --color=hl+:#2ac3de \
  --color=hl:#2ac3de \
  --color=info:#545c7e \
  --color=marker:#ff007c \
  --color=pointer:#ff007c \
  --color=prompt:#2ac3de \
  --color=query:#c0caf5:regular \
  --color=scrollbar:#27a1b9 \
  --color=separator:#ff9e64 \
  --color=spinner:#ff007c \
"

# Shortcut to making exicutable.
alias plusx="chmod +x"
alias vim="nvim"
alias v="nvim"
alias rl="source ~/.zshrc"

if (( $+commands[bat] )); then
    alias cat="bat"
elif (( $+commands[batcat] )); then
    alias cat="batcat"
fi

if (( $+commands[eza] )); then
    export EZA_CONFIG_DIR=$XDG_CONFIG_HOME/eza/
    alias l='eza --no-git --all'
    alias ls="eza --no-git --long --header --git --icons --all --group-directories-first"
    alias tree="eza --no-git --tree --level=3"
else
    alias ls='ls -lah'
    alias l="ls -lah"
fi

alias myip="wget -qO- https://wtfismyip.com/text"
alias x="exit"

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

notebooks() {
    cd "`gofind find notebooks`"
}

obs() {
    local vault_path=$(gofind find notebooks)
    open "obsidian://open?path=${vault_path}"
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

if [[ -s $DOTFILES_DIR/secrets/.env.local ]]; then
    set -a
    source $DOTFILES_DIR/secrets/.env.local
    set +a
fi

alias rgnb="rg -- "


# Difftastic
export DFT_BACKGROUND=dark
export DFT_DISPLAY=inline

# Tokyo Night theme colors for gum
export GUM_SPIN_SPINNER_FOREGROUND="#7aa2f7"  # Tokyo Night blue
export GUM_SPIN_TITLE_FOREGROUND="#c0caf5"    # Tokyo Night foreground
export GUM_CHOOSE_CURSOR_FOREGROUND="#7aa2f7" # Tokyo Night blue
export GUM_CHOOSE_ITEM_FOREGROUND="#c0caf5"   # Tokyo Night foreground
export GUM_CHOOSE_SELECTED_FOREGROUND="#16161e" # Tokyo Night dark
export GUM_CHOOSE_SELECTED_BACKGROUND="#7aa2f7" # Tokyo Night blue
export GUM_INPUT_CURSOR_FOREGROUND="#7aa2f7"  # Tokyo Night blue
export GUM_INPUT_PROMPT_FOREGROUND="#c0caf5"  # Tokyo Night foreground
export GUM_FILTER_INDICATOR_FOREGROUND="#7aa2f7" # Tokyo Night blue
export GUM_FILTER_MATCH_FOREGROUND="#f7768e"  # Tokyo Night red
export GUM_CONFIRM_PROMPT_FOREGROUND="#c0caf5" # Tokyo Night foreground
export GUM_CONFIRM_SELECTED_FOREGROUND="#9ece6a" # Tokyo Night green
export GUM_CONFIRM_UNSELECTED_FOREGROUND="#545c7e" # Tokyo Night comment

alias k="kubectl"
alias hv="tmux new-session -As hive hive"

k9z() {
  local context namespace cmd

  # Select context
  context=$(kubectl config get-contexts -o name | fzf --prompt="Select context: ")
  [[ -z "$context" ]] && return 1

  # Select namespace (default if empty)
  namespace=$(kubectl get ns --context "$context" -o jsonpath='{.items[*].metadata.name}' \
    | tr ' ' '\n' | fzf --prompt="Select namespace (default if empty): ")
  [[ -z "$namespace" ]] && namespace="default"

  # Build final command
  cmd="k9s --context \"$context\" --namespace \"$namespace\""

  # Add to history (zsh way)
  print -s "$cmd"

  # Run it
  echo "$cmd"
  eval "$cmd"
}

eval "$(starship init zsh)"

# Custom Completions
PROG="scaffold" source $DOTFILES_DIR/files/urfave_completions.zsh
source <(mi completion zsh)

# Load system local zshconfig if exists
[[ -f "$HOME/.zshrc.system" ]] && source "$HOME/.zshrc.system"
export SOPS_AGE_KEY_FILE=~/.age/key.txt
