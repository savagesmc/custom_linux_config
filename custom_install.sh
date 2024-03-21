#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "CUSTOM INSTALL"

if [[ ! -d ~/.oh-my-zsh/custom/themes/powerlevel9k ]]; then
   git clone https://github.com/bhilburn/powerlevel9k.git ~/.oh-my-zsh/custom/themes/powerlevel9k
fi

## rm -rf ~/user_install
## mkdir -p ~/user_install

mkdir -p ~/.config

ln -sf ${DIR}/nvim_config ~/.config/nvim

case "$(uname -s)" in

   Darwin)
     echo 'export EDITOR=/usr/local/bin/nvim' >> ~/.zshrc
     ;;

esac

