#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "CUSTOM INSTALL"

if [[ ! -d ~/.oh-my-zsh/custom/themes/powerlevel9k ]]; then
   git clone https://github.com/bhilburn/powerlevel9k.git ~/.oh-my-zsh/custom/themes/powerlevel9k
fi

## rm -rf ~/user_install
## mkdir -p ~/user_install

mkdir -p ~/.config

if [ -d ~/.config/nvim ] && [ ! -L ~/.config/nvim ]; then
    echo "WARNING: ~/.config/nvim is a regular directory (Neovim auto-created it). Removing and replacing with symlink."
    rm -rf ~/.config/nvim
fi
ln -sf ${DIR}/nvim_config ~/.config/nvim

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

# === Install AI coding tools ===
echo ""
echo "--- AI tools ---"

# OpenCode CLI
if command -v opencode >/dev/null 2>&1; then
    echo "OpenCode is already installed: $(command -v opencode)"
else
    echo "Installing OpenCode..."
    OPENCODE_INSTALLED=0

    if command -v npm >/dev/null 2>&1; then
        NPM_OUTPUT=$(npm install -g opencode-ai 2>&1)
        if [ $? -eq 0 ]; then
            echo "OpenCode installed via npm"
            OPENCODE_INSTALLED=1
        else
            echo "WARNING: npm install -g opencode-ai failed"
            echo "${NPM_OUTPUT}" | while IFS= read -r line; do echo "  $line"; done
            if [ -n "${http_proxy}${https_proxy}${HTTP_PROXY}${HTTPS_PROXY}" ]; then
                echo "  Proxy is set — check that npm proxy config matches:"
                echo "  npm config get proxy && npm config get https-proxy"
            fi
            if echo "${NPM_OUTPUT}" | grep -qi "EACCES\|permission"; then
                echo "  Hint: use 'npm config set prefix ~/.npm-global' to avoid sudo"
            fi
        fi
    fi

    if [ $OPENCODE_INSTALLED -eq 0 ] && command -v brew >/dev/null 2>&1; then
        if brew install anomalyco/tap/opencode 2>&1; then
            echo "OpenCode installed via Homebrew"
            OPENCODE_INSTALLED=1
        else
            echo "WARNING: brew install anomalyco/tap/opencode failed"
        fi
    fi

    if [ $OPENCODE_INSTALLED -eq 0 ]; then
        echo "WARNING: Could not install OpenCode automatically."
        echo "  Install manually: curl -fsSL https://opencode.ai/install | bash"
    fi
fi

# Ollama (optional local LLM runner)
if command -v ollama >/dev/null 2>&1; then
    echo "Ollama is available: $(command -v ollama)"
else
    echo "Ollama not found (optional — for local LLM models)"
    echo "  Install: curl -fsSL https://ollama.com/install.sh | sh"
fi

# OpenRouter API key check
if [ -z "${OPENROUTER_API_KEY}" ]; then
    echo "WARNING: OPENROUTER_API_KEY is not set."
    echo "  Set it in ~/.env (outside the managed section): export OPENROUTER_API_KEY=sk-or-v1-..."
    echo "  Get a key at: https://openrouter.ai/keys"
fi

# === Add env vars to ~/.env (idempotent — survives reinstalls) ===
# ~/.env infrastructure (creation, source in zshrc/bashrc, EDITOR) is handled by linux_config/install.sh

# EDITOR (set on non-Darwin where base installer doesn't do it)
if ! grep -q "^export EDITOR=" ~/.env 2>/dev/null; then
    EDITOR_PATH=$(command -v nvim 2>/dev/null || echo /usr/local/bin/nvim)
    echo "export EDITOR=${EDITOR_PATH}" >> ~/.env
fi

# OPENCODE_CONFIG
if ! grep -q "OPENCODE_CONFIG" ~/.env 2>/dev/null; then
    cat >> ~/.env << 'ENVEOF'

# OpenCode local providers config
if [ -f ~/.config/opencode/local-providers.json ]; then
    export OPENCODE_CONFIG=~/.config/opencode/local-providers.json
fi
ENVEOF
    echo "Added OPENCODE_CONFIG to ~/.env"
fi

