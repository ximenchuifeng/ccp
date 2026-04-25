# ccp v0.0.1 — Claude Code Provider Switcher

A zsh-based multi-provider switcher for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Different terminals can use different providers simultaneously. Includes VS Code extension config sync.

[中文文档](ccp/README.zh-CN.md)

## Features

- **Multi-provider switching** — Shell env vars control the LLM backend, isolated per terminal
- **VS Code sync** — Write provider config into VS Code `settings.json` for the Claude Code extension
- **Auto onboarding bypass** — Skip OAuth login prompts automatically
- **Config diagnostics** — Detect env conflicts, VS Code plugin status, and more

## Installation

```sh
git clone https://github.com/ximenchuifeng/ccp.git && cd ccp
bash install.sh
```

Add to `~/.zshrc`:

```sh
ccp() { source "$HOME/.local/share/cc-provider/cc-provider.sh" "$@"; }
```

Reload:

```sh
source ~/.zshrc
```

## Configuration

Edit `~/.local/share/cc-provider/providers.conf`:

```ini
[profile://openrouter]
name         = OpenRouter
base_url     = https://openrouter.ai/api
api_key      = ${ENV:OPENROUTER_API_KEY}
model        = claude-sonnet-4-6
sonnet_model = claude-sonnet-4-6
haiku_model  = claude-haiku-4-5
opus_model   = claude-opus-4-6

[profile://kimi]
name         = Kimi
base_url     = https://api.kimi.com/coding/
auth_token   = ${ENV:KIMI_API_KEY}
model        = kimi-k2.5

[profile://glm]
name         = GLM-5.1
base_url     = https://open.bigmodel.cn/api/anthropic
auth_token   = ${ENV:GLM_API_KEY}
model        = glm-5.1
```

Secrets can be plain text or use `${ENV:VAR_NAME}` to read from environment variables (recommended).

## Supported Environment Variables

| Config Field | Environment Variable | Description |
|---|---|---|
| `base_url` | `ANTHROPIC_BASE_URL` | API endpoint |
| `api_key` | `ANTHROPIC_API_KEY` | API key |
| `auth_token` | `ANTHROPIC_AUTH_TOKEN` | Auth token |
| `model` | `ANTHROPIC_MODEL` | Default model |
| `haiku_model` | `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Haiku model |
| `sonnet_model` | `ANTHROPIC_DEFAULT_SONNET_MODEL` | Sonnet model |
| `opus_model` | `ANTHROPIC_DEFAULT_OPUS_MODEL` | Opus model |

## Usage

```sh
ccp glm             # Switch to glm and launch Claude Code
ccp                  # Interactive menu, then launch Claude Code
ccp use kimi         # Switch env vars only (no launch)
ccp sync-vscode      # Interactive: select provider → sync to VS Code
ccp sync-vscode glm  # Sync glm directly to VS Code settings.json
ccp status           # Show current provider status
ccp list             # List all configured profiles
ccp edit             # Open config file in editor
ccp doctor           # Diagnose config conflicts (incl. VS Code)
ccp reset            # Reset to Anthropic official (clears VS Code too)
ccp uninstall        # Remove ccp completely
```

## VS Code Extension Support

`ccp sync-vscode` writes the selected provider's env vars into VS Code `settings.json` under `claudeCode.environmentVariables`. It also auto-enables:

- `claudeCode.disableLoginPrompt: true`
- `claudeCode.hideOnboarding: true`

`ccp use <name>` auto-syncs to VS Code when switching providers in the terminal.

## Notes

- If `~/.claude/settings.json` has an `env` block with the same variables, it overrides shell env vars. `ccp doctor` detects this conflict.
- zsh only.
- Requires python3 (pre-installed on macOS).
