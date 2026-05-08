#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Remove .agents symlink
if [ -L ~/.agents ]; then
    rm -f ~/.agents
    echo "Removed ~/.agents symlink"
elif [ -d ~/.agents ]; then
    echo "WARNING: ~/.agents exists and is not a symlink, leaving it alone"
fi

# Remove nvim config symlink
if [ -L ~/.config/nvim ]; then
    rm -f ~/.config/nvim
    echo "Removed ~/.config/nvim symlink"
elif [ -d ~/.config/nvim ]; then
    echo "WARNING: ~/.config/nvim exists and is not a symlink, leaving it alone"
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

# Remove OPENCODE_CONFIG block from ~/.env
if [ -f ~/.env ] && grep -q "OPENCODE_CONFIG" ~/.env 2>/dev/null; then
    tmpfile=$(mktemp)
    skip=0
    while IFS= read -r line; do
        if echo "$line" | grep -q "^# OpenCode local providers config$"; then
            skip=1
            continue
        fi
        if [ $skip -eq 1 ] && echo "$line" | grep -q "^fi$"; then
            skip=0
            continue
        fi
        [ $skip -eq 0 ] && echo "$line"
    done < ~/.env > "$tmpfile"
    mv "$tmpfile" ~/.env
    echo "Removed OPENCODE_CONFIG from ~/.env"
fi

# Remove powerlevel9k if installed by custom_install.sh
if [ -d ~/.oh-my-zsh/custom/themes/powerlevel9k ]; then
    rm -rf ~/.oh-my-zsh/custom/themes/powerlevel9k
    echo "Removed powerlevel9k theme"
fi
