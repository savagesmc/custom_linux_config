# Coding Agent Support

## Architecture

This repo stores the common configuration for opencode (the AI coding agent) and symlinks them into place on each machine.

### Config Structure

OpenCode merges configuration from multiple sources. The key insight is using the `OPENCODE_CONFIG` environment variable 
to point to a machine-specific config file that gets merged with the main `opencode.json`.

```
custom_linux_config/
├── opencode/
│   ├── opencode.json              # Common config (tracked in git)
│   ├── local-providers-example.json  # Template for local providers (tracked)
│   └── agent/                     # Agent definitions (tracked)
│       ├── coder.md
│       ├── researcher.md
│       ├── reviewer.md
│       └── scribe.md
├── agents/                        # .agents folder content (tracked)
│   └── skills/
└── custom_install.sh              # Installs everything
```

### What's Common (tracked in git)

- **`opencode/opencode.json`** — Shared config: plugins, MCP (context7), openrouter provider, agent definitions
- **`opencode/agent/`** — Agent prompt files (coder, researcher, reviewer, scribe)
- **`agents/`** — Agent skills

### What's Machine-Specific (not tracked)

- **`~/.config/opencode/local-providers.json`** — Local model providers (vllm, lmstudio, llama.cpp). Each machine may have different local models or endpoints.

## Setup on a New Machine

Run the installer from the parent `linux_config` repo:

```bash
../linux_config/install.sh
```

This will:

1. Symlink `~/.agents` → `custom_linux_config/agents`
2. Symlink `~/.config/opencode/opencode.json` → `custom_linux_config/opencode/opencode.json`
3. Symlink `~/.config/opencode/agent` → `custom_linux_config/opencode/agent`
4. Copy `local-providers-example.json` → `local-providers.json` (one-time, if not present)
5. Add `OPENCODE_CONFIG` to `~/.zshrc` (one-time, if not present)

## Adding Machine-Specific Local Providers

Edit `~/.config/opencode/local-providers.json` directly. This file is **not** tracked in git (it's in `.gitignore`).

To add a new local model provider, follow the existing patterns:

```json
{
  "provider": {
    "my_local_provider": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "My Local Model",
      "options": {
        "baseURL": "http://localhost:PORT/v1"
      },
      "models": {
        "model-id": {
          "name": "Display Name"
        }
      }
    }
  }
}
```

## Editing Common Config

To modify the common config, edit `opencode/opencode.json` in this repo and commit the changes. After committing, pull the changes on any machine and the symlink will automatically reflect the updates.

## Editing Agent Definitions

Agent prompt files live in `opencode/agent/`. Edit them directly in the repo and commit. The symlink in `~/.config/opencode/agent` will reflect changes immediately.

## How OPENCODE_CONFIG Works

OpenCode merges the config at `OPENCODE_CONFIG` with the main `~/.config/opencode/opencode.json`. This means:

- Keys from `local-providers.json` are merged into the main config
- Provider definitions are combined (openrouter from main, local from `local-providers.json`)
- Non-conflicting settings from both files are preserved

## Troubleshooting

### "Model not found" after adding a local provider

Make sure the `baseURL` in `local-providers.json` matches your machine's actual endpoint.

### Config not picking up changes

Ensure `OPENCODE_CONFIG` is set:
```bash
echo $OPENCODE_CONFIG
# Should output: ~/.config/opencode/local-providers.json
```

If not set, source your zshrc or restart your terminal.

### Symlink broken

```bash
# Check symlinks
ls -la ~/.agents
ls -la ~/.config/opencode/opencode.json
ls -la ~/.config/opencode/agent

# Fix if needed (run from custom_linux_config directory)
ln -sf $(pwd)/agents ~/.agents
ln -sf $(pwd)/opencode/opencode.json ~/.config/opencode/opencode.json
ln -sf $(pwd)/opencode/agent ~/.config/opencode/agent
```
