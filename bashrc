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

export ANDROID_HOME=${HOME}/Library/Android/sdk
export PATH=${PATH}:${ANDROID_HOME}/tools
export PATH=${PATH}:${ANDROID_HOME}/platform-tools
export NDK_ROOT="${HOME}/android-ndk-r7"
export ANDROID_SDK_ROOT="${HOME}/android-sdk-mac_x86"
export ANDROID_NDK_ROOT="$NDK_ROOT"
export PATH=$PATH:$ANDROID_NDK_ROOT:/usr/local/sbin/:$HOME/neovim/bin:$HOME/.go/bin
export PATH=/Users/logankopas/Library/Android/sdk/tools:$PATH
export PATH=/Users/logankopas/Library/Android/sdk/platform-tools:$PATH
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
if [ -f $(brew --prefix)/etc/bash_completion ]; then
    . $(brew --prefix)/etc/bash_completion
fi
# for f in /usr/local/etc/bash_completion.d/*; do
#     source $f
# done

export EDITOR="vi"

# for when django misbehaves
killpy(){
    kill -9 `ps aux | grep 'manage\.py runserver' | grep -v grep | tr -s " " | cut -d" " -f2`
}

# for when django really misbehaves
killcelery(){
    for a in `ps aux |grep celery |grep -v grep| tr -s " " |cut -d" " -f2 | tr  "\n" " "`; 
    do 
        kill $a; 
    done
}

# for when django REALLY REALLY misbehaves
killrabbit(){
    for a in `ps aux | grep rabbit | grep -v grep | tr -s " " | cut -d" " -f2`;
    do
        kill $a
    done
}

# this one happens a lot
killmysql(){
    kill -9 `ps aux | grep 'mysql' | grep -v grep | tr -s " " | cut -d" " -f2`;
}

## Git helper commands - I use a lot of long branch names
# search for git branch
gf ()
{
    if [ `git branch | grep "$1" | wc -l` -gt 1 ]; then
        echo "Too many matches, use 'git branch' manually";
        return;
    elif [ `git branch | grep "$1" | wc -l` -lt 1 ]; then
        echo "No branch found"
        return;
    fi;
    git branch | grep --color=auto "$1"
}

# this one is specific to our release branches, hotfixes are prepended with a release name and timestamp
# this just finds the release info and strips the whitespace for subbing in to the hotfix branch name
gr ()
{
    git branch | grep --color=auto "$1$" | cut -d/ -f3
}

# nvbn/thefuck
# awesome repo, screws up my git history though :/
eval "$(thefuck --alias)"

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# fbr - checkout git branch (including remote branches)

# fzf commands
# checkout a branch or remote branch
fbr() {
  local branches branch
  branches=$(git branch --all | grep -v HEAD) &&
  branch=$(echo "$branches" |
           fzf-tmux -d $(( 2 + $(wc -l <<< "$branches") )) +m) &&
  git checkout $(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
}

# fd - cd to selected directory
fd() {
  local dir
  dir=$(find ${1:-*} -path '*/\.*' -prune \
                  -o -type d -print 2> /dev/null | fzf +m) &&
  cd "$dir"
}

gitroot(){
    echo `git rev-parse --show-toplevel`
}
rmsync() {
    mkdir empty && rsync -r --delete empty/ $1 && rmdir $1 
}
rebuild_venv(){
    . ~/work/regiondb/venv/bin/activate
    pip freeze | xargs pip uninstall -y
    env "CFLAGS=-I/usr/local/include -L/usr/local/lib" pip install -r ~/work/regiondb/requirements/dev.txt
    pip install pudb bpython django_extensions neovim
}
mkcd(){
    mkdir -p $1
    cd $1
}
start_ngrok() {
URL=`curl http://localhost:4040/api/tunnels | jq '.tunnels | .[0] | .public_url' | tail -1`;
echo starting ngrok with url: $URL ;
sed -e"s^TWILIO_URL_PREFIX =.*# logan keep this updated^TWILIO_URL_PREFIX = $URL  # logan keep this updated^g" -i".orig" ~/work/regiondb/regiondb/deploy_settings/local_override.py;
}
confirm () {
# call with a prompt string or use a default
read -r -p "${1:-Are you sure? [y/N]} " response
case $response in
    [yY][eE][sS]|[yY])
        true
        ;;
    *)
        false
        ;;
esac
}
clean(){
find . -name "$1";
confirm && find . -name "$1" | xargs rm || echo "Aborted";
}

# The next line updates PATH for the Google Cloud SDK.
if [ -f /Users/logankopas/Downloads/google-cloud-sdk/path.bash.inc ]; then
  source '/Users/logankopas/Downloads/google-cloud-sdk/path.bash.inc'
fi

# The next line enables shell command completion for gcloud.
if [ -f /Users/logankopas/Downloads/google-cloud-sdk/completion.bash.inc ]; then
  source '/Users/logankopas/Downloads/google-cloud-sdk/completion.bash.inc'
fi

orig ()
{
    # copies a file with a .orig extension
    if [ -e "$1.orig" ]; then
        echo "exists";
        return;
    fi;
    if [ -e $1 ]; then
        cp $1 $1.orig;
        echo "copied";
        return;
    fi;
    touch $1.orig;
    echo "created"
}
