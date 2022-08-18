#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ ! -d ~/.oh-my-zsh/custom/themes/powerlevel9k ]]; then
   git clone https://github.com/bhilburn/powerlevel9k.git ~/.oh-my-zsh/custom/themes/powerlevel9k
fi

if [ -e /usr/bin/apt-get ]; then
  sudo apt-get update -y
  sudo apt-get install -y build-essential cmake python3-dev neovim python3-neovim
  sudo apt-get install -y python3-dev python3-pip python3-setuptools
elif [[ $(which brew) ]]; then
  brew install python3 cmake llvm
  # TODO:
fi

if [[ -d ~/.vim/plugged/YouCompleteMe ]]; then
   pushd ~/.vim/plugged/YouCompleteMe
   python3 ./install.py --clang-completer
   popd
fi

#Install neovim plugins
nvim \
    "+PlugInstall" \
    "+qall"

