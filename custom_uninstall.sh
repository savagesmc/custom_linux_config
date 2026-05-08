#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Remove .agents symlink
if [ -L ~/.agents ]; then
    rm -f ~/.agents
    echo "Removed ~/.agents symlink"
elif [ -d ~/.agents ]; then
    echo "WARNING: ~/.agents exists and is not a symlink, leaving it alone"
fi

# Remove opencode symlinks and files
if [ -L ~/.config/opencode/opencode.json ]; then
    rm -f ~/.config/opencode/opencode.json
    echo "Removed ~/.config/opencode/opencode.json symlink"
elif [ -f ~/.config/opencode/opencode.json ]; then
    echo "WARNING: ~/.config/opencode/opencode.json exists and is not a symlink, leaving it alone"
fi

if [ -L ~/.config/opencode/agent ]; then
    rm -f ~/.config/opencode/agent
    echo "Removed ~/.config/opencode/agent symlink"
elif [ -d ~/.config/opencode/agent ]; then
    echo "WARNING: ~/.config/opencode/agent exists and is not a symlink, leaving it alone"
fi

# Remove local-providers.json (machine-specific, not tracked in git)
if [ -f ~/.config/opencode/local-providers.json ]; then
    rm -f ~/.config/opencode/local-providers.json
    echo "Removed ~/.config/opencode/local-providers.json"
fi

# Remove OPENCODE_CONFIG block from ~/.zshrc
if grep -q "OPENCODE_CONFIG" ~/.zshrc 2>/dev/null; then
    sed -i '' '/^# OpenCode local providers config$/,/^fi$/d' ~/.zshrc
    echo "Removed OPENCODE_CONFIG from ~/.zshrc"
fi

# Remove EDITOR export added by custom_install.sh (Darwin only)
if uname -s | grep -q Darwin; then
    if grep -q "export EDITOR=/usr/local/bin/nvim" ~/.zshrc 2>/dev/null; then
        sed -i '' '/export EDITOR=\/usr\/local\/bin\/nvim/d' ~/.zshrc
        echo "Removed EDITOR export from ~/.zshrc"
    fi
fi

# Remove powerpower9k if installed by custom_install.sh
if [ -d ~/.oh-my-zsh/custom/themes/powerpower9k ]; then
    rm -rf ~/.oh-my-zsh/custom/themes/powerpower9k
    echo "Removed powerpower9k theme"
fi
