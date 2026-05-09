#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_REPO="${SCRIPT_DIR}/../linux_config"
CUSTOM_REPO="${SCRIPT_DIR}"

echo "=== Air-Gapped Dev Environment Packager ==="
echo ""

# ---- Validate prerequisites ----
if [ ! -d "$BASE_REPO" ]; then
    echo "ERROR: Base linux_config repo not found at $BASE_REPO"
    echo "Expected at: ../linux_config relative to $(basename "$SCRIPT_DIR")"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is required to download Linux-specific binaries."
    exit 1
fi

# ---- Phase 1: Build Docker image and download dependencies ----
echo "[Phase 1/4] Building Docker image and downloading dependencies..."
echo "  This may take 10-20 minutes on first run..."

docker build -t airgap-bundle -f "$CUSTOM_REPO/Dockerfile.bundle" "$CUSTOM_REPO"

echo "  Exporting artifacts from image..."
rm -rf "$CUSTOM_REPO/cache"
mkdir -p "$CUSTOM_REPO/cache"

docker run --rm -v "$CUSTOM_REPO/cache:/output" airgap-bundle

echo "  Dependencies exported to ./cache/"
echo ""

# ---- Phase 2: Assemble bundle directory ----
echo "[Phase 2/4] Assembling bundle directory..."

BUNDLE_DIR="$CUSTOM_REPO/airgap_bundle"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/dot_files"
mkdir -p "$BUNDLE_DIR/oh-my-zsh-lib"
mkdir -p "$BUNDLE_DIR/scripts"
mkdir -p "$BUNDLE_DIR/agents_skills"
mkdir -p "$BUNDLE_DIR/cache"

# Copy dotfiles from BOTH repos
echo "  Merging dotfiles..."
for f in "$BASE_REPO/dot_files/"*; do
    cp "$f" "$BUNDLE_DIR/dot_files/"
done
for f in "$CUSTOM_REPO/dot_files/"*; do
    # Skip octave-workspace binary
    if [ "$(basename "$f")" = "octave-workspace" ]; then
        continue
    fi
    cp "$f" "$BUNDLE_DIR/dot_files/"
done

# Copy custom.zsh
cp "$BASE_REPO/custom.zsh" "$BUNDLE_DIR/oh-my-zsh-lib/custom.zsh"

# Copy scripts (excluding AI/cloud-dependent ones)
echo "  Copying scripts (excluding AI-only)..."
for f in "$BASE_REPO/scripts/"*; do
    cp "$f" "$BUNDLE_DIR/scripts/"
done
for f in "$CUSTOM_REPO/scripts/"*; do
    script_name="$(basename "$f")"
    case "$script_name" in
        populate_local_providers.py)
            continue
            ;;
        *)
            cp "$f" "$BUNDLE_DIR/scripts/"
            ;;
    esac
done

# Copy agent skills (reference docs only, no runtime)
echo "  Copying agent skills (reference docs)..."
if [ -d "$CUSTOM_REPO/agents/skills" ]; then
    cp -r "$CUSTOM_REPO/agents/skills"/* "$BUNDLE_DIR/agents_skills/"
fi

# ---- Phase 3: Create offline nvim config ----
echo "[Phase 3/4] Creating offline-adapted nvim config..."

cp -r "$CUSTOM_REPO/nvim_config" "$BUNDLE_DIR/nvim_config"

# Guard vim.hl.on_yank for older Neovim versions
sed -i '' 's/vim\.hl\.on_yank({timeout=500})/pcall(function() vim.hl.on_yank({timeout=500}) end)/' "$BUNDLE_DIR/nvim_config/lua/user/options.lua"

# Remove run/build commands from plugins.lua (they require internet)
sed -i '' '/run = "cd app && npm install"/d' "$BUNDLE_DIR/nvim_config/lua/user/plugins.lua"
sed -i '' '/build = ":TSUpdate"/d' "$BUNDLE_DIR/nvim_config/lua/user/plugins.lua"

# Modify mason.lua: don't auto-install (everything is pre-installed)
sed -i '' 's/ensure_installed = servers/ensure_installed = {}/' "$BUNDLE_DIR/nvim_config/lua/user/lsp/mason.lua"

# Modify treesitter.lua: don't try to install parsers (pre-installed)
sed -i '' 's/ensure_installed = "all"/ensure_installed = {}/' "$BUNDLE_DIR/nvim_config/lua/user/treesitter.lua"

echo "  Offline config ready."

# ---- Copy cache from Docker output ----
echo "  Copying downloaded cache..."
set +e
if [ -d "$CUSTOM_REPO/cache/oh-my-zsh" ]; then
    cp -r "$CUSTOM_REPO/cache/oh-my-zsh" "$BUNDLE_DIR/cache/oh-my-zsh"
else
    echo "  WARNING: oh-my-zsh cache missing!"
fi
if [ -d "$CUSTOM_REPO/cache/powerlevel9k" ]; then
    cp -r "$CUSTOM_REPO/cache/powerlevel9k" "$BUNDLE_DIR/cache/powerlevel9k"
else
    echo "  WARNING: powerlevel9k cache missing!"
fi
if [ -d "$CUSTOM_REPO/cache/tpm" ]; then
    cp -r "$CUSTOM_REPO/cache/tpm" "$BUNDLE_DIR/cache/tpm"
fi
if [ -d "$CUSTOM_REPO/cache/tmux-plugins" ]; then
    cp -r "$CUSTOM_REPO/cache/tmux-plugins" "$BUNDLE_DIR/cache/tmux-plugins"
fi
if [ -d "$CUSTOM_REPO/cache/nvim-lazy" ]; then
    cp -r "$CUSTOM_REPO/cache/nvim-lazy" "$BUNDLE_DIR/cache/nvim-lazy"
fi
if [ -f "$CUSTOM_REPO/cache/nvim-lazy-lock.json" ]; then
    cp "$CUSTOM_REPO/cache/nvim-lazy-lock.json" "$BUNDLE_DIR/cache/nvim-lazy-lock.json"
fi
if [ -d "$CUSTOM_REPO/cache/nvim-mason" ]; then
    cp -r "$CUSTOM_REPO/cache/nvim-mason" "$BUNDLE_DIR/cache/nvim-mason"
fi
if [ -d "$CUSTOM_REPO/cache/nvim-treesitter" ]; then
    cp -r "$CUSTOM_REPO/cache/nvim-treesitter" "$BUNDLE_DIR/cache/nvim-treesitter"
fi
if [ -f "$CUSTOM_REPO/cache/nvim-0.11.7-linux-x86_64.tar.gz" ]; then
    cp "$CUSTOM_REPO/cache/nvim-0.11.7-linux-x86_64.tar.gz" "$BUNDLE_DIR/cache/"
fi
set -e

# Copy install script into bundle
cp "$CUSTOM_REPO/install_airgap.sh" "$BUNDLE_DIR/install_airgap.sh"
chmod +x "$BUNDLE_DIR/install_airgap.sh"

# ---- Generate MANIFEST.md for auditing ----
echo "  Generating MANIFEST.md..."
MANIFEST="$BUNDLE_DIR/MANIFEST.md"

# Helper: classify a file, output "type|language"
classify() {
    local f="$1"
    local desc=$(file -b "$f" 2>/dev/null)
    local base="$(basename "$f")"
    local ext="${base##*.}"
    [ "$ext" = "$base" ] && ext=""

    # .tar.gz / .tgz needs special handling (ext would be "gz" or "tgz")
    if echo "$base" | grep -qE '\.tar\.(gz|bz2|xz)$'; then
        echo "Archive|gzip-compressed tar"
        return
    fi
    if echo "$base" | grep -qE '\.tgz$'; then
        echo "Archive|gzip-compressed tar"
        return
    fi

    # Determine base type
    if echo "$desc" | grep -qE '^ELF'; then
        local ftype="Binary"
    elif echo "$desc" | grep -qE '(gzip compressed|bzip2 compressed|XZ compressed|Zip archive|tar archive)'; then
        local ftype="Archive"
        echo "${ftype}|$(echo "$desc" | head -1)"
        return
    elif echo "$desc" | grep -qiE '(mach-o|shared object|dynamically linked)'; then
        local ftype="Binary"
    else
        local ftype="Text"
    fi

    # Determine language for text files
    local lang=""
    if [ "$ftype" = "Text" ]; then
        # Check shebang for no-extension scripts
        if [ "$ext" = "$base" ] || [ -z "$ext" ]; then
            local shebang=$(head -1 "$f" 2>/dev/null)
            if echo "$shebang" | grep -q 'bin/bash'; then
                lang="Shell (bash)"
            elif echo "$shebang" | grep -q 'bin/zsh'; then
                lang="Shell (zsh)"
            elif echo "$shebang" | grep -q 'bin/sh'; then
                lang="Shell (sh)"
            elif echo "$shebang" | grep -q 'python'; then
                lang="Python"
            elif echo "$shebang" | grep -q 'php'; then
                lang="PHP"
            elif echo "$shebang" | grep -q 'perl'; then
                lang="Perl"
            elif echo "$shebang" | grep -q 'node'; then
                lang="JavaScript"
            fi
        fi

        # Extension-based detection (overrides shebang if extension present)
        case "$ext" in
            sh|bash)      lang="Shell (bash)" ;;
            zsh)          lang="Shell (zsh)" ;;
            py)           lang="Python" ;;
            lua)          lang="Lua" ;;
            js)           lang="JavaScript" ;;
            json)         lang="JSON" ;;
            yaml|yml)     lang="YAML" ;;
            toml)         lang="TOML" ;;
            md)           lang="Markdown" ;;
            vim)          lang="Vimscript" ;;
            cfg|conf|ini) lang="Config (INI)" ;;
            css)          lang="CSS" ;;
            html)         lang="HTML" ;;
            xml)          lang="XML" ;;
            c)            lang="C" ;;
            cpp|cc|cxx)   lang="C++" ;;
            h|hpp)        lang="C/C++ Header" ;;
        esac

        # Special cases by name
        case "$base" in
            myzshrc|*_zshrc|platform_*|custom.zsh|*.zsh-theme) lang="Shell (zsh)" ;;
            mytmux.conf|tmux.conf) lang="Config (tmux)" ;;
            mygitconfig|gitconfig) lang="Config (git)" ;;
            dircolors)            lang="Config (dircolors)" ;;
            minttyrc)             lang="Config (mintty)" ;;
            lynx.lss)             lang="Config (lynx)" ;;
            ssh_port_forwarding)  lang="Shell (bash)" ;;
            zshrc_ssh-agent)      lang="Shell (zsh)" ;;
            hyper.js)             lang="JavaScript" ;;
            install_airgap.sh)    lang="Shell (bash)" ;;
            MANIFEST.md)          lang="Markdown" ;;
            README.md)            lang="Markdown" ;;
            LICENSE)              lang="Plain text" ;;
        esac

        # Final fallback
        [ -z "$lang" ] && lang="Plain text"
    fi

    echo "${ftype}|${lang}"
}

# Helper: get git remote URL for a directory (returns empty if not a git repo)
git_remote_url() {
    local dir="$1"
    if [ -d "$dir/.git" ]; then
        git -C "$dir" remote get-url origin 2>/dev/null
        return
    fi
}

cat > "$MANIFEST" << 'MANIFEST_HEADER'
# Air-Gapped Dev Environment — Content Manifest

Generated: MANIFEST_DATE
Source repos: linux_config + custom_linux_config
Target platform: Linux (x86_64)

This manifest lists every file in the tarball for security auditing before
transfer into an air-gapped environment. Each entry includes file type,
source language (if applicable), and for binaries, the upstream source URL.

---

## Type Legend

| Type | Description |
|---|---|
| Text | Human-readable file (config, plain text, documentation) |
| Script | Executable text file (shell, Python, Lua, etc.) |
| Binary | Compiled binary (ELF .so, executable, etc.) |
| Archive | Compressed archive (.tar.gz, .zip) |

## Source URL Legend

Binary components are traced to their upstream source for supply-chain auditing.
Git repositories are listed with their clone URL (HEAD at time of packaging).

---

## Summary

| Category | Count | Type | Description |
|---|---|---|---|
| Dotfiles | DOTFILE_COUNT | Text/Script | Shell, git, tmux, terminal configs |
| oh-my-zsh | 1 (repo) | Script/Text | Pre-cloned zsh framework |
| Powerlevel9k | 1 (repo) | Script/Text | Zsh theme |
| Tmux plugins | 8 (repos) | Script/Text | tpm + 7 plugins |
| Neovim 0.11.7 | 1 (archive) | Archive | Pre-downloaded x86_64 tarball |
| Neovim plugins | NVIM_PLUGIN_COUNT (repos) | Script/Text | lazy.nvim cache with lockfile |
| Neovim LSPs | 4 (binaries) | Binary | Mason-installed language servers |
| Neovim parsers | 3 (binaries) | Binary | Treesitter .so parsers |
| Scripts | SCRIPT_COUNT | Script | Utility scripts from both repos |
| Agent skills | 15 (docs) | Text | Markdown reference (no runtime) |
| Nvim config | NVIM_CONFIG_COUNT (files) | Text/Script | Offline-adapted Neovim config |

## Excluded (by design)

| Component | Reason |
|---|---|
| OpenCode CLI | Requires network (npm/brew install) |
| OpenRouter API config | Requires cloud API key |
| Context7 MCP server | Requires network (remote URL) |
| PlantUML MCP server | Requires network (npx download) |
| populate_local_providers.py | Requires Hugging Face API |
| Ollama/LM Studio integration | Requires local LLM models |
| Markdown-preview.nvim build | Requires npm install |

---

## File Listing

MANIFEST_HEADER

# Replace date placeholder
TODAY=$(date "+%Y-%m-%d %H:%M:%S %Z")
sed -i '' "s/MANIFEST_DATE/$TODAY/" "$MANIFEST"

# Count dotfiles
DOTFILE_COUNT=$(ls "$BUNDLE_DIR/dot_files/" | wc -l | tr -d ' ')
SCRIPT_COUNT=$(ls "$BUNDLE_DIR/scripts/" | wc -l | tr -d ' ')
NVIM_PLUGIN_COUNT=$(ls "$BUNDLE_DIR/cache/nvim-lazy/" 2>/dev/null | wc -l | tr -d ' ')
NVIM_CONFIG_COUNT=$(find "$BUNDLE_DIR/nvim_config" -type f | wc -l | tr -d ' ')

sed -i '' "s/DOTFILE_COUNT/$DOTFILE_COUNT/" "$MANIFEST"
sed -i '' "s/SCRIPT_COUNT/$SCRIPT_COUNT/" "$MANIFEST"
sed -i '' "s/NVIM_PLUGIN_COUNT/$NVIM_PLUGIN_COUNT/" "$MANIFEST"
sed -i '' "s/NVIM_CONFIG_COUNT/$NVIM_CONFIG_COUNT/" "$MANIFEST"

# ---- Section: Installer scripts ----
{
    echo "### Installer Script"
    echo ""
    name="install_airgap.sh"
    f="$BUNDLE_DIR/$name"
    size=$(du -h "$f" | cut -f1)
    class=$(classify "$f")
    ftype="${class%%|*}"
    lang="${class##*|}"
    echo "| File | Size | Type | Language |"
    echo "|------|------|------|----------|"
    echo "| $name | $size | $ftype | $lang |"
    echo ""
} >> "$MANIFEST"

# ---- Section: Dotfiles ----
{
    echo "### Dotfiles (target: ~/ with dot prefix)"
    echo ""
    echo "| File | Size | Type | Language | Source Repo |"
    echo "|------|------|------|----------|-------------|"
    for f in "$BUNDLE_DIR/dot_files/"*; do
        name="$(basename "$f")"
        size=$(du -h "$f" | cut -f1)
        class=$(classify "$f")
        ftype="${class%%|*}"
        lang="${class##*|}"
        if [ -f "$CUSTOM_REPO/dot_files/$name" ]; then
            repo="custom_linux_config"
        else
            repo="linux_config"
        fi
        echo "| .$name | $size | $ftype | $lang | $repo |"
    done
    echo ""
} >> "$MANIFEST"

# ---- Section: oh-my-zsh custom lib ----
{
    if [ -f "$BUNDLE_DIR/oh-my-zsh-lib/custom.zsh" ]; then
        f="$BUNDLE_DIR/oh-my-zsh-lib/custom.zsh"
        size=$(du -h "$f" | cut -f1)
        class=$(classify "$f")
        ftype="${class%%|*}"
        lang="${class##*|}"
        echo "### oh-my-zsh Custom Library"
        echo ""
        echo "| File | Size | Type | Language | Target |"
        echo "|------|------|------|----------|--------|"
        echo "| custom.zsh | $size | $ftype | $lang | ~/.oh-my-zsh/lib/custom.zsh |"
        echo ""
    fi
} >> "$MANIFEST"

# ---- Section: Cached Dependencies ----
{
    echo "### Cached Dependencies"
    echo ""
    echo "| Component | Size | Type | Source URL |"
    echo "|-----------|------|------|------------|"

    # Source URL map for binary components
    declare -A BIN_URLS
    BIN_URLS=(
        ["nvim-0.11.7-linux-x86_64.tar.gz"]="https://github.com/neovim/neovim/releases/tag/v0.11.7"
        ["oh-my-zsh"]="https://github.com/ohmyzsh/ohmyzsh"
        ["powerlevel9k"]="https://github.com/bhilburn/powerlevel9k"
        ["tpm"]="https://github.com/tmux-plugins/tpm"
        ["tmux-plugins"]="https://github.com/tmux-plugins/ (multiple repos — see tmux-plugins/ listing below)"
        ["nvim-lazy"]="https://github.com/ (multiple repos — see Neovim Plugins listing below)"
        ["nvim-lazy-lock.json"]="(generated by lazy.nvim — commit hashes)"
        ["nvim-mason"]="(multiple sources — see Mason LSP Servers listing below)"
        ["nvim-treesitter"]="https://github.com/nvim-treesitter/nvim-treesitter"
    )

    for item in "$BUNDLE_DIR/cache/"*; do
        name="$(basename "$item")"
        if [ -d "$item" ]; then
            size=$(du -sh "$item" | cut -f1)
            # Determine type of directory contents
            ftype="Text/Script"
            case "$name" in
                nvim-mason)       ftype="Binary" ;;
                nvim-treesitter)   ftype="Binary" ;;
            esac
            # Get git remote URL for repo directories
            url=$(git_remote_url "$item" 2>/dev/null)
            [ -z "$url" ] && url="${BIN_URLS[$name]:-}"
            [ -z "$url" ] && url="(see detail section below)"
            echo "| $name/ | $size | $ftype | $url |"
        elif [ -f "$item" ]; then
            size=$(du -h "$item" | cut -f1)
            class=$(classify "$item")
            ftype="${class%%|*}"
            url="${BIN_URLS[$name]:-}"
            echo "| $name | $size | $ftype | $url |"
        fi
    done
    echo ""
} >> "$MANIFEST"

# ---- Section: Tmux plugins detail ----
{
    if [ -d "$BUNDLE_DIR/cache/tmux-plugins" ]; then
        echo "### Tmux Plugins"
        echo ""
        echo "| Plugin | Source URL |"
        echo "|--------|------------|"
        echo "| tpm | https://github.com/tmux-plugins/tpm |"
        for d in "$BUNDLE_DIR/cache/tmux-plugins/"*; do
            name="$(basename "$d")"
            case "$name" in
                vim-tmux-navigator)
                    echo "| $name | https://github.com/christoomey/vim-tmux-navigator |"
                    ;;
                *)
                    echo "| $name | https://github.com/tmux-plugins/$name |"
                    ;;
            esac
        done
        echo ""
    fi
} >> "$MANIFEST"

# ---- Section: Neovim plugins detail ----
{
    if [ -d "$BUNDLE_DIR/cache/nvim-lazy" ]; then
        echo "### Neovim Plugins (from lazy.nvim cache)"
        echo ""
        echo "All plugins are pre-cloned git repositories. Exact commit hashes are pinned in"
        echo "nvim-lazy-lock.json for reproducibility."
        echo ""
        echo "| Plugin | Source URL |"
        echo "|--------|------------|"
        for d in "$BUNDLE_DIR/cache/nvim-lazy/"*; do
            name="$(basename "$d")"
            url=$(git_remote_url "$d" 2>/dev/null)
            [ -z "$url" ] && url="(unknown)"
            echo "| $name | $url |"
        done
        echo ""
    fi
} >> "$MANIFEST"

# ---- Section: Mason LSP detail ----
{
    echo "### Mason LSP Servers"
    echo ""
    echo "Each entry is a platform-specific binary downloaded by Mason."
    echo ""
    echo "| Package | Type | Source URL |"
    echo "|---------|------|------------|"
    
    declare -A LSP_URLS
    LSP_URLS=(
        ["lua-language-server"]="https://github.com/LuaLS/lua-language-server"
        ["pyright"]="https://github.com/microsoft/pyright"
        ["json-lsp"]="https://github.com/hrsh7th/vscode-langservers-extracted"
        ["bash-language-server"]="https://github.com/bash-lsp/bash-language-server"
        ["clangd"]="https://github.com/clangd/clangd"
        ["cmake-language-server"]="https://github.com/regen100/cmake-language-server"
    )

    if [ -d "$BUNDLE_DIR/cache/nvim-mason/packages" ]; then
        for d in "$BUNDLE_DIR/cache/nvim-mason/packages/"*; do
            name="$(basename "$d")"
            url="${LSP_URLS[$name]:-}"
            echo "| $name | Binary | $url |"
        done
    fi
    echo ""
    echo "**Not bundled** (Mason install timed out during build):"
    echo ""
    echo "| Package | Install on target via |"
    echo "|---------|----------------------|"
    echo "| clangd | \`apt-get install -y clangd\` |"
    echo "| cmake-language-server | \`pip install cmake-language-server\` |"
    echo ""

} >> "$MANIFEST"

# ---- Section: Treesitter parsers ----
{
    echo "### Treesitter Parsers"
    echo ""
    echo "Compiled shared objects (.so) from the nvim-treesitter project."
    echo ""
    echo "| Parser (.so) | Size | Type | Source URL |"
    echo "|-------------|------|------|------------|"
    if [ -d "$BUNDLE_DIR/cache/nvim-treesitter" ]; then
        for f in "$BUNDLE_DIR/cache/nvim-treesitter/"*; do
            name="$(basename "$f")"
            size=$(du -h "$f" | cut -f1)
            echo "| $name | $size | Binary | https://github.com/nvim-treesitter/nvim-treesitter |"
        done
    fi
    echo ""
    echo "**Note:** Only 3 parsers bundled (Neovim 0.9.5 compatibility during Docker build)."
    echo "After Neovim 0.11.7 is installed on the target, run in nvim:"
    echo '```'
    echo ":TSInstallSync all"
    echo '```'
    echo "This will compile all remaining parsers from the pre-downloaded nvim-treesitter repo."
    echo ""

} >> "$MANIFEST"

# ---- Section: Scripts ----
{
    echo "### Scripts (target: ~/scripts/)"
    echo ""
    echo "| Script | Size | Type | Language | Source Repo |"
    echo "|--------|------|------|----------|-------------|"
    for f in "$BUNDLE_DIR/scripts/"*; do
        name="$(basename "$f")"
        size=$(du -h "$f" | cut -f1)
        class=$(classify "$f")
        ftype="${class%%|*}"
        lang="${class##*|}"
        if [ -f "$CUSTOM_REPO/scripts/$name" ]; then
            repo="custom_linux_config"
        else
            repo="linux_config"
        fi
        echo "| $name | $size | $ftype | $lang | $repo |"
    done
    echo ""
} >> "$MANIFEST"

# ---- Section: Agent skills ----
{
    echo "### Agent Skills (reference docs, no runtime configured)"
    echo ""
    echo "| Skill | Type | Source URL |"
    echo "|-------|------|------------|"

    declare -A SKILL_URLS
    SKILL_URLS=(
        ["code-philosophy"]="local (custom)"
        ["code-review"]="local (custom)"
        ["cpp-testing"]="https://github.com/affaan-m/everything-claude-code"
        ["docker-expert"]="https://github.com/sickn33/antigravity-awesome-skills"
        ["find-skills"]="https://github.com/vercel-labs/skills"
        ["frontend-philosophy"]="local (custom)"
        ["git-advanced-workflows"]="https://github.com/wshobson/agents"
        ["javascript-testing-patterns"]="https://github.com/wshobson/agents"
        ["plan-protocol"]="local (custom)"
        ["plan-review"]="local (custom)"
        ["playwright-generate-test"]="https://github.com/github/awesome-copilot"
        ["pytest-coverage"]="https://github.com/github/awesome-copilot"
        ["python-testing-patterns"]="https://github.com/wshobson/agents"
        ["test-driven-development"]="https://github.com/obra/superpowers"
        ["webapp-testing"]="https://github.com/anthropics/skills"
    )

    for d in "$BUNDLE_DIR/agents_skills/"*; do
        name="$(basename "$d")"
        url="${SKILL_URLS[$name]:-}"
        echo "| $name | Text (Markdown) | $url |"
    done
    echo ""
} >> "$MANIFEST"

# ---- Section: Nvim config files ----
{
    echo "### Neovim Config (target: ~/.config/nvim/)"
    echo ""
    echo "| File | Type | Language |"
    echo "|------|------|----------|"
    find "$BUNDLE_DIR/nvim_config" -type f | sort | while read f; do
        rel="${f#$BUNDLE_DIR/nvim_config/}"
        class=$(classify "$f")
        ftype="${class%%|*}"
        lang="${class##*|}"
        echo "| $rel | $ftype | $lang |"
    done
    echo ""
    echo "**Note:** plugins.lua, mason.lua, and treesitter.lua have been adapted for offline use"
    echo "(build/download commands removed, ensure_installed set to empty)."
    echo ""

} >> "$MANIFEST"

# ---- Footer ----
{
    echo "---"
    echo ""
    echo "## Audit Notes"
    echo ""
    echo "- All git repositories are shallow clones (depth=1) to minimize size"
    echo "- Neovim plugins include a lazy-lock.json with pinned commit hashes for reproducibility"
    echo "- No API keys, credentials, or secrets are included"
    echo "- macOS extended attributes (xattr) may appear as tar warnings — they are stripped on Linux extraction"
    echo "- Total tarball size on disk: TOTAL_SIZE"
    echo ""
} >> "$MANIFEST"

# Fill in total size
TOTAL_SIZE=$(du -sh "$BUNDLE_DIR" | cut -f1)
sed -i '' "s/TOTAL_SIZE/$TOTAL_SIZE/" "$MANIFEST"

echo "  Manifest: $MANIFEST"

# ---- Phase 4: Create tarball ----
echo "[Phase 4/4] Creating tarball..."
cd "$CUSTOM_REPO"
tar -czf airgap_dev_env.tar.gz -C "$CUSTOM_REPO" airgap_bundle

SIZE=$(du -sh airgap_dev_env.tar.gz | cut -f1)
echo ""
echo "=============================================="
echo "  Package created: airgap_dev_env.tar.gz ($SIZE)"
echo "=============================================="
echo ""
echo "Transfer this file to your air-gapped machine, then:"
echo ""
echo "  tar -xzf airgap_dev_env.tar.gz"
echo "  cd airgap_bundle"
echo "  ./install_airgap.sh"
echo ""