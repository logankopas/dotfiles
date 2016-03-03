#
# ~/.bash_aliases
#

# allow non-interactive shells (vim) to use aliases
shopt -s expand_aliases

# so many ways to use ls
alias ls='ls -G'
alias ll='ls -alhF'
alias la='ls -A'
alias l='ls -CF'

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias gs='git status'

alias s='cd ..'

# another cool git alias, gets the name of the current branch, 
# I use it for ``` git push origin `cb` ```
alias cb='git branch | grep "*" | cut -d" " -f2'

# we were having troubles with people commiting and/or changing pycharm .idea files
alias fuck_pycharm='ls .idea/* | xargs -L1 git update-index --assume-unchanged'

# I was having troubles with MacVim
alias vim="DYLD_FORCE_FLAT_NAMESPACE=1 /Applications/MacVim.app/Contents/MacOS/Vim"
alias less="less -r"

# glances is a cool program, like a lightweight htop
alias glances="glances --theme-white"

# rsync is WAAAAAY better than cp or scp
alias cp="rsync"
