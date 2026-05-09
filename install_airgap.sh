#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "=== Air-Gapped Dev Environment Installer ==="
echo "Bundle: $BUNDLE_DIR"
echo ""

# ---- 1. Install oh-my-zsh ----
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "[1/11] Installing oh-my-zsh..."
    cp -r "$BUNDLE_DIR/cache/oh-my-zsh" "$HOME/.oh-my-zsh"
else
    echo "[1/11] oh-my-zsh already installed, skipping."
fi

# ---- 2. Setup zsh ----
echo "[2/11] Configuring zsh..."
cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"

cat >> "$HOME/.zshrc" << 'ZSH_EOF'

# Air-gapped environment settings
export no_share_history=1
export DISABLE_AUTO_UPDATE="true"
[[ -f ~/.env ]] && source ~/.env
ZSH_EOF

# ---- 3. Symlink custom.zsh into oh-my-zsh ----
echo "[3/11] Installing custom.zsh..."
ln -sf "$BUNDLE_DIR/oh-my-zsh-lib/custom.zsh" "$HOME/.oh-my-zsh/lib/custom.zsh"

# ---- 4. Symlink dotfiles ----
echo "[4/11] Symlinking dotfiles..."
for f in "$BUNDLE_DIR/dot_files/"*; do
    name=".$(basename "$f")"
    ln -sf "$f" "$HOME/$name"
done

# ---- 5. Install powerlevel9k theme ----
echo "[5/11] Installing powerlevel9k theme..."
mkdir -p "$HOME/.oh-my-zsh/custom/themes"
if [ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel9k" ]; then
    cp -r "$BUNDLE_DIR/cache/powerlevel9k" "$HOME/.oh-my-zsh/custom/themes/powerlevel9k"
fi

# ---- 6. Install tmux plugins ----
echo "[6/11] Installing tmux plugins..."
mkdir -p "$HOME/.tmux/plugins"
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    cp -r "$BUNDLE_DIR/cache/tpm" "$HOME/.tmux/plugins/tpm"
fi
for plugin_dir in "$BUNDLE_DIR/cache/tmux-plugins/"*; do
    name="$(basename "$plugin_dir")"
    if [ ! -d "$HOME/.tmux/plugins/$name" ]; then
        cp -r "$plugin_dir" "$HOME/.tmux/plugins/$name"
    fi
done
ln -sf "$BUNDLE_DIR/scripts/update_display.sh" "$HOME/.tmux/update_display.sh"

# ---- 7. Install scripts ----
echo "[7/11] Installing scripts..."
mkdir -p "$HOME/scripts"
for f in "$BUNDLE_DIR/scripts/"*; do
    ln -sf "$f" "$HOME/scripts/$(basename "$f")"
done

# ---- 8. Setup neovim ----
echo "[8/11] Setting up Neovim..."
mkdir -p "$HOME/.config"
if [ -d "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
    rm -rf "$HOME/.config/nvim"
fi
ln -sf "$BUNDLE_DIR/nvim_config" "$HOME/.config/nvim"

# Pre-populate lazy.nvim plugins
mkdir -p "$HOME/.local/share/nvim/lazy"
if [ -d "$BUNDLE_DIR/cache/nvim-lazy" ]; then
    for d in "$BUNDLE_DIR/cache/nvim-lazy/"*; do
        name="$(basename "$d")"
        if [ ! -d "$HOME/.local/share/nvim/lazy/$name" ]; then
            cp -r "$d" "$HOME/.local/share/nvim/lazy/$name"
        fi
    done
fi

# Copy lockfile so lazy.nvim doesn't try to git fetch
if [ -f "$BUNDLE_DIR/cache/nvim-lazy-lock.json" ]; then
    cp "$BUNDLE_DIR/cache/nvim-lazy-lock.json" "$HOME/.config/nvim/lazy-lock.json"
fi

# Pre-populate Mason LSP packages
mkdir -p "$HOME/.local/share/nvim/mason"
if [ -d "$BUNDLE_DIR/cache/nvim-mason/packages" ]; then
    cp -r "$BUNDLE_DIR/cache/nvim-mason/packages" "$HOME/.local/share/nvim/mason/packages"
fi
if [ -d "$BUNDLE_DIR/cache/nvim-mason/bin" ]; then
    cp -r "$BUNDLE_DIR/cache/nvim-mason/bin" "$HOME/.local/share/nvim/mason/bin"
fi
if [ -d "$BUNDLE_DIR/cache/nvim-mason/.registry" ]; then
    cp -r "$BUNDLE_DIR/cache/nvim-mason/.registry" "$HOME/.local/share/nvim/mason/.registry"
fi

# Pre-populate Treesitter parsers
mkdir -p "$HOME/.local/share/nvim/site/parser"
if [ -d "$BUNDLE_DIR/cache/nvim-treesitter" ]; then
    cp "$BUNDLE_DIR/cache/nvim-treesitter/"* "$HOME/.local/share/nvim/site/parser/" 2>/dev/null || true
fi

# ---- 8b. Install Neovim 0.11.7 if needed ----
NEED_NVIM=0
if ! command -v nvim &> /dev/null; then
    NEED_NVIM=1
else
    NVIM_VER=$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if [ -z "$NVIM_VER" ] || [ "$(printf '%s\n' "0.11" "$NVIM_VER" | sort -V | head -1)" != "0.11" ]; then
        NEED_NVIM=1
    fi
fi
if [ "$NEED_NVIM" -eq 1 ] && [ -f "$BUNDLE_DIR/cache/nvim-0.11.7-linux-x86_64.tar.gz" ]; then
    echo "  Installing Neovim 0.11.7 to ~/.local/..."
    mkdir -p "$HOME/.local"
    tar xzf "$BUNDLE_DIR/cache/nvim-0.11.7-linux-x86_64.tar.gz" -C "$HOME/.local" --strip-components=1
    echo "  Neovim 0.11.7 installed."
elif [ "$NEED_NVIM" -eq 1 ]; then
    echo "  WARNING: Neovim 0.11+ not found and no tarball in bundle."
    echo "  Some plugins (Telescope, Treesitter) may not work."
fi

# ---- 9. Symlink agent skills (reference docs only, no agent runtime) ----
echo "[9/11] Installing agent skills (reference docs)..."
ln -sf "$BUNDLE_DIR/agents_skills" "$HOME/.agents"

# ---- 10. Setup ~/.env ----
echo "[10/11] Configuring ~/.env..."
if [ ! -f "$HOME/.env" ]; then
    cat > "$HOME/.env" << 'EOF'
# Dotfile environment variables (survives reinstalls)
EOF
fi

if ! grep -q "EDITOR=" "$HOME/.env" 2>/dev/null; then
    echo 'export EDITOR=nvim' >> "$HOME/.env"
fi

# ---- 11. Platform-specific notes ----
echo "[11/11] Finalizing..."
echo ""
echo "=============================================="
echo "  Installation complete!"
echo "=============================================="
echo ""
echo "Start a new zsh session:  exec zsh"
echo "Start tmux:               tmux"
echo "Start neovim:             nvim"
echo ""
echo "Notes:"
echo "  - AI coding agents are disabled (no network)"
echo "  - Agent skills are at ~/.agents (reference docs only)"
echo "  - Mason LSP servers are pre-installed in ~/.local/share/nvim/mason/"
echo "  - Changes to ~/.env persist across reinstalls"
echo ""
