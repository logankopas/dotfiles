#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# log every command to ~/.logs
# this isn't working :(
export PROMPT_COMMAND='if [ "$(id -u)" -ne 0 ]; then echo "$(date "+%Y-%m-%d.%H:%M:%S") $(pwd) $(history 1)" >> ~/.logs/bash-history-$(date "+%Y-%m-%d").log; fi'


# from github mrzool/bash-sensible
# pretty cool repo, there's some great settings in there,
# but needs the latest bash to use them all
if [ -f ~/.sensible.bash ]; then
   source ~/.sensible.bash
fi

# Most people think having a fancy bash prompt is a waste of time,
# but have you ever had to search your terminal for the start of a 
# command because your prompt is the same colour as the output?

DARKGRAY='\e[1;30m'
LIGHTRED='\e[1;31m'
GREEN='\e[32m'
YELLOW='\e[1;33m'
LIGHTBLUE='\e[1;34m'
RED='\e[31m'
NC='\e[m'

# prompt -> [username]$
PS1='\[\e[1;31m\][\u]\[\e[1;34m\]\$\[\e[0m\] '

# Fix backspace for neovim and iTerm
infocmp $TERM | sed 's/kbs=^[hH]/kbs=\\177/' >| $TERM.ti
tic $TERM.ti

export ANDROID_HOME=${HOME}/Library/Android/sdk
export PATH=${PATH}:${ANDROID_HOME}/tools
export PATH=${PATH}:${ANDROID_HOME}/platform-tools
export NDK_ROOT="${HOME}/android-ndk-r7"
export ANDROID_SDK_ROOT="${HOME}/android-sdk-mac_x86"
export ANDROID_NDK_ROOT="$NDK_ROOT"
export PATH=$PATH:$ANDROID_NDK_ROOT:/usr/local/sbin/:$HOME/neovim/bin:$HOME/bin
export PYTHONSTARTUP=~/.pythonrc
export THEFUCK_ALTER_HISTORY=false
export GOPATH=~/.go
export PGDATA=/usr/local/var/postgres

# private stuff, like homebrew github tokens
[[ -e ~/.tokens ]] && . ~/.tokens

# cool shortcuts
[[ -e ~/.bash_aliases ]] && . ~/.bash_aliases

[[ -e ~/dotfiles/j.sh ]] && . ~/dotfiles/j.sh

# autocompletes
#if [ -f $(brew --prefix)/etc/bash_completion ]; then
#    . $(brew --prefix)/etc/bash_completion
#fi
# for f in /usr/local/etc/bash_completion.d/*; do
#     source $f
# done

export EDITOR="vi"

[[ -e ~/.fun.sh ]] && . ~/.fun.sh
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
complete -f -X '*.zip' rmzip
