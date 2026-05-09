#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Air-Gapped Install Test ==="
echo ""

# ---- 1. Build the package if it doesn't exist ----
if [ ! -f "$SCRIPT_DIR/airgap_dev_env.tar.gz" ]; then
    echo "[1/3] Building package..."
    bash "$SCRIPT_DIR/package_for_airgap.sh"
else
    echo "[1/3] Package already exists: airgap_dev_env.tar.gz"
fi

# ---- 2. Spin up clean Ubuntu container and install ----
echo "[2/3] Testing install in clean Ubuntu container..."

CONTAINER_NAME="airgap-test-$$"
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

# Start container with only base prerequisites
docker run -d --name "$CONTAINER_NAME" \
    ubuntu:24.04 \
    sleep infinity

# Install base prerequisites (simulating what the user has)
docker exec "$CONTAINER_NAME" bash -c "
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq && apt-get install -y -qq --no-install-recommends \
        neovim git zsh tmux python3 nodejs npm curl \
        > /dev/null 2>&1
"

# Copy the tarball
docker cp "$SCRIPT_DIR/airgap_dev_env.tar.gz" "$CONTAINER_NAME:/tmp/airgap_dev_env.tar.gz"

# Extract and install
docker exec "$CONTAINER_NAME" bash -c "
    cd /tmp
    tar -xzf airgap_dev_env.tar.gz
    cd airgap_bundle
    bash install_airgap.sh
"

echo ""

# ---- 3. Verify the installation ----
echo "[3/3] Verifying installation..."

PASS_COUNT=0
FAIL_COUNT=0

check() {
    local desc="$1"
    local cmd="$2"
    echo -n "  [$desc] ... "
    if docker exec "$CONTAINER_NAME" bash -c "$cmd" > /dev/null 2>&1; then
        echo "PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

echo "  --- Basic structure checks ---"
check "~/.oh-my-zsh exists"            "test -d ~/.oh-my-zsh"
check "~/.zshrc exists"                "test -f ~/.zshrc"
check "~/.bashrc symlink"              "test -L ~/.bashrc"
check "~/.gitconfig symlink"           "test -L ~/.gitconfig"
check "~/.mygitconfig symlink"         "test -L ~/.mygitconfig"
check "~/.tmux.conf symlink"           "test -L ~/.tmux.conf"
check "~/.mytmux.conf symlink"         "test -L ~/.mytmux.conf"
check "~/.myzshrc symlink"             "test -L ~/.myzshrc"
check "~/.env exists"                  "test -f ~/.env"
check "~/.env has EDITOR=nvim"         "grep -q 'EDITOR=nvim' ~/.env"

echo "  --- Tmux checks ---"
check "~/.tmux/plugins/tpm exists"     "test -d ~/.tmux/plugins/tpm"
check "~/.tmux/plugins/tmux-sensible"  "test -d ~/.tmux/plugins/tmux-sensible"
check "~/.tmux/plugins/tmux-resurrect" "test -d ~/.tmux/plugins/tmux-resurrect"
check "~/.tmux/plugins/vim-tmux-navigator" "test -d ~/.tmux/plugins/vim-tmux-navigator"
check "~/.tmux/update_display.sh"      "test -L ~/.tmux/update_display.sh"

echo "  --- Neovim checks ---"
check "~/.config/nvim symlink"         "test -L ~/.config/nvim"
check "nvim --headless +qa exits"      "nvim --headless +qa 2>&1"
check "nvim lazy.nvim loaded"          "nvim --headless -c 'lua if pcall(require, \"lazy\") then vim.cmd(\"qa\") else vim.cmd(\"cq\") end' 2>&1"

echo "  --- Script checks ---"
check "~/scripts/findp exists"         "test -L ~/scripts/findp"
check "~/scripts/key exists"           "test -L ~/scripts/key"
check "~/scripts/show_colors exists"   "test -L ~/scripts/show_colors"
check "populate_local_providers EXCLUDED" "test ! -e ~/scripts/populate_local_providers.py"

echo "  --- Agent checks ---"
check "~/.agents symlink exists"       "test -L ~/.agents"
check "agent skills present"           "test -d ~/.agents/code-philosophy"
check "no opencode config"             "test ! -e ~/.config/opencode"

echo "  --- Git config checks ---"
check "gitconfig includes mygitconfig"  "git config --global --includes 2>/dev/null || git config --list --show-origin 2>/dev/null | grep -q mygitconfig"

echo ""
echo "=============================================="
echo "  Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "=============================================="

# Cleanup
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo ""
    echo "Some checks FAILED. Review the output above."
    exit 1
else
    echo ""
    echo "All checks passed! Package is ready for transfer."
fi
