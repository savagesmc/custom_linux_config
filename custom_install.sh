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

# AI coding agent support

# Symlink .agents folder
if [ -L ~/.agents ]; then
    echo "Already linked ~/.agents -> $(readlink ~/.agents)"
elif [ -d ~/.agents ]; then
    echo "WARNING: ~/.agents exists and is not a symlink, skipping"
else
    ln -sf ${DIR}/agents ~/.agents
    echo "Linked ~/.agents -> ${DIR}/agents"
fi

# Set up opencode config
mkdir -p ~/.config/opencode

# Symlink opencode.json
if [ -L ~/.config/opencode/opencode.json ]; then
    echo "Already linked ~/.config/opencode/opencode.json"
elif [ -f ~/.config/opencode/opencode.json ]; then
    echo "WARNING: ~/.config/opencode/opencode.json exists and is not a symlink, skipping"
else
    ln -sf ${DIR}/opencode/opencode.json ~/.config/opencode/opencode.json
    echo "Linked ~/.config/opencode/opencode.json -> ${DIR}/opencode/opencode.json"
fi

# Symlink agent folder
if [ -L ~/.config/opencode/agent ]; then
    echo "Already linked ~/.config/opencode/agent"
elif [ -d ~/.config/opencode/agent ]; then
    echo "WARNING: ~/.config/opencode/agent exists and is not a symlink, skipping"
else
    ln -sf ${DIR}/opencode/agent ~/.config/opencode/agent
    echo "Linked ~/.config/opencode/agent -> ${DIR}/opencode/agent"
fi

# Copy local-providers-example.json if local-providers.json doesn't exist yet
if [ ! -f ~/.config/opencode/local-providers.json ]; then
    cp ${DIR}/opencode/local-providers-example.json ~/.config/opencode/local-providers.json
    echo "Copied local-providers-example.json -> local-providers.json (edit this file for your local models)"
fi

# Add OPENCODE_CONFIG to .zshrc if not already present
if ! grep -q "OPENCODE_CONFIG" ~/.zshrc 2>/dev/null; then
    cat >> ~/.zshrc << 'ZSHRC_EOF'

# OpenCode local providers config
if [ -f ~/.config/opencode/local-providers.json ]; then
    export OPENCODE_CONFIG=~/.config/opencode/local-providers.json
fi
ZSHRC_EOF
    echo "Added OPENCODE_CONFIG to ~/.zshrc"
fi

