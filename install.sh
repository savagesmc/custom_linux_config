#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
./uninstall.sh
source ${DIR}/functions.sh
install_files

if [[ ! -d ~/.oh-my-zsh/custom/themes/powerlevel9k ]]; then
   git clone https://github.com/bhilburn/powerlevel9k.git ~/.oh-my-zsh/custom/themes/powerlevel9k
fi
