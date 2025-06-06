#!/usr/bin/env bash

# Get Path to script folder
DIR="$( cd "$( dirname "$0" )" && pwd )"
# Fix path in case of symlinks
DIR=$(cd "$DIR" && pwd -P)

# Check for .dotfiles file and add symlink
dotfiles="$HOME/dotfiles"
if [ -L $dotfiles ]; then
    echo "Removing existing $dotfiles symlink"
    rm $dotfiles
fi

# If installing from ~/dotfiles, then don't copy.
if [ $dotfiles != $DIR ]; then
    if [ -d $dotfiles ]; then
        echo "Found existing $dotfiles folder."
        echo "Overwrite it? (y/n)"
        read response
        if [ $response == 'y' -o $response == 'Y' ]; then
            echo "Removing existing $DIR"
            rm -rf $dotfiles
            echo "Copying $DIR -> $dotfiles"
            cp -r "$DIR" "$dotfiles"
        else
            echo "Cowardly refusing to install."
            exit
        fi
    else
        echo "Copying $DIR => $dotfiles"
        cp -r "$DIR" "$dotfiles"
    fi
fi

# Recursively map dotfiles to home directory
echo "Linking dotfiles..."
#for file in bashrc bash_aliases bash_profile vimrc tmux.conf gitconfig pythonrc git_template zshrc;  do
for file in bashrc bash_aliases bash_profile vimrc tmux.conf gitconfig pythonrc git_template;  do
    target="$HOME/.$file"
    if [ -L $target ]; then
        rm $target
    fi
    if [ -f $target ]; then
         echo "*** $file file exists, cowardly refusing to overwrite it."
     else
         ln -s "$dotfiles/$file" "$target"
         echo -e "Linked ~/.$file"
     fi
done

# Load up new profile
echo "Loading Profile"
source ~/.bash_profile

# Neovim
target="${HOME}/.config/nvim"
if [ -L $target ]; then
    rm $target
fi
if [ -d $target ]; then
    echo "*** $target exists, cowardly refusing to overwrite it."
else
    ln -s "${dotfiles}/nvim" "$target"
    echo -e "Linked $target"
fi

