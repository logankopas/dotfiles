# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=/home/logan/.oh-my-zsh

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="bira"

# Set list of themes to load
# Setting this variable when ZSH_THEME=random
# cause zsh load theme from this variable instead of
# looking in ~/.oh-my-zsh/themes/
# An empty array have no effect
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.

plugins=(
  git
  zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
#
[[ -e ~/.fun.sh ]] && . ~/.fun.sh
[[ -e ~/.bash_aliases ]] && . ~/.bash_aliases

export PATH=~/uni/bin:~/bin:$PATH
  [ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/ljk003/google-cloud-sdk/path.zsh.inc' ]; then source '/Users/ljk003/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/ljk003/google-cloud-sdk/completion.zsh.inc' ]; then source '/Users/ljk003/google-cloud-sdk/completion.zsh.inc'; fi


. "$HOME/.local/share/../bin/env"

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

. "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# kimi-code
export PATH="/home/logan/.kimi-code/bin:$PATH"

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"

# Load the ZedDocs deploy key with a timeout and open a forwarding session into the agent container.
#   zeddocs                      15-minute key, plain login shell
#   zeddocs 1h                   1-hour key
#   zeddocs 30m tmux attach      30-minute key, straight into tmux
# Keep the session open while the key is needed: closing it removes the forwarded socket.
export ZEDDOCS_KEY=~/.ssh/zeddocs_ed25519
export ZEDDOCS_CONTAINER=agent
zeddocs() {
    local key=${ZEDDOCS_KEY:-$HOME/.ssh/zeddocs-deploy}      # path to the private key
    local host=${ZEDDOCS_CONTAINER:-agent-container}         # the Host alias for the container
    local ttl=${1:-15m}
    local sock=$HOME/.ssh/zeddocs-agent.sock
    (( $# )) && shift

    # A local agent of our own: a forwarded agent refuses `ssh-add -t`.
    # ssh-add -l exits 2 when no agent answers on the socket, so start one only then.
    SSH_AUTH_SOCK=$sock ssh-add -l >/dev/null 2>&1
    if (( $? == 2 )); then
        rm -f -- $sock
        ssh-agent -a $sock >/dev/null || { print -u2 "zeddocs: could not start ssh-agent"; return 1 }
    fi

    SSH_AUTH_SOCK=$sock ssh-add -t $ttl -- $key || return 1
    SSH_AUTH_SOCK=$sock ssh -A -t $host "$@"
}

  # Drop the key before its timeout.
  zeddocs-drop() { SSH_AUTH_SOCK=$HOME/.ssh/zeddocs-agent.sock ssh-add -D }
