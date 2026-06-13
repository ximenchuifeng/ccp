# ccp v0.0.1 — Claude Code Provider Switcher

A zsh-based multi-provider switcher for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Different terminals can use different providers simultaneously. Includes VS Code extension config sync.

[中文文档](ccp/README.zh-CN.md)

## Features

- **Multi-provider switching** — Shell env vars control the LLM backend, isolated per terminal
- **VS Code sync** — Write provider config into VS Code `settings.json` for the Claude Code extension
- **Auto onboarding bypass** — Skip OAuth login prompts automatically
- **Config diagnostics** — Detect env conflicts, VS Code plugin status, and more
- **Accurate profile tracking** — `ccp status` and the interactive menu correctly identify the active profile, even when multiple profiles share the same `base_url`

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
name                = Kimi
base_url            = https://api.kimi.com/coding/
auth_token          = ${ENV:KIMI_API_KEY}
model               = kimi-k2.6
haiku_model         = kimi-k2.6
sonnet_model        = kimi-k2.6
opus_model          = kimi-k2.6
subagent_model      = kimi-k2.6
enable_tool_search  = false
auto_compact_window = 262144
autocompact_pct     = 85

[profile://glm]
name                = GLM-5.1
base_url            = https://open.bigmodel.cn/api/anthropic
auth_token          = ${ENV:GLM_API_KEY}
model               = glm-5.1
haiku_model         = glm-5.1
sonnet_model        = glm-5.1
opus_model          = glm-5.1
subagent_model      = glm-5.1
enable_tool_search  = false
auto_compact_window = 204800
autocompact_pct     = 85
disable_traffic     = 1
effort_level        = max

[profile://deepseek]
name                = DeepSeek
base_url            = https://api.deepseek.com/anthropic
auth_token          = ${ENV:DEEPSEEK_API_KEY}
model               = deepseek-v4-pro[1m]
haiku_model         = deepseek-v4-flash
sonnet_model        = deepseek-v4-pro
opus_model          = deepseek-v4-pro
subagent_model      = deepseek-v4-flash
enable_tool_search  = false
auto_compact_window = 1048576
autocompact_pct     = 85
disable_traffic     = 1
effort_level        = max

[profile://glm52]
name                = GLM-5.2
base_url            = https://open.bigmodel.cn/api/anthropic
auth_token          = ${ENV:GLM_API_KEY}
model               = glm-5.2[1m]
haiku_model         = glm-5.2
sonnet_model        = glm-5.2
opus_model          = glm-5.2
subagent_model      = glm-5.2
enable_tool_search  = false
auto_compact_window = 1048576
autocompact_pct     = 85
disable_traffic     = 1
effort_level        = max

[profile://kimi-k2.7-code]
name                = Kimi K2.7 Code
base_url            = https://api.kimi.com/coding/
auth_token          = ${ENV:KIMI_API_KEY}
model               = kimi-k2.7-code
haiku_model         = kimi-k2.7-code
sonnet_model        = kimi-k2.7-code
opus_model          = kimi-k2.7-code
subagent_model      = kimi-k2.7-code
enable_tool_search  = false
auto_compact_window = 262144
autocompact_pct     = 85
disable_traffic     = 1
effort_level        = max
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
| `disable_traffic` | `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | Disable telemetry/updates (set to `1`) |
| `effort_level` | `CLAUDE_CODE_EFFORT_LEVEL` | Reasoning effort (e.g. `max`) |
| `subagent_model` | `CLAUDE_CODE_SUBAGENT_MODEL` | Subagent model (e.g. same as `model`) |
| `enable_tool_search` | `ENABLE_TOOL_SEARCH` | Tool search toggle (e.g. `false`) |
| `auto_compact_window` | `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | Auto-compaction context window (e.g. `262144`) |
| `autocompact_pct` | `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | Auto-compaction trigger percentage (e.g. `85`) |

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

## Reinstall / Uninstall

To completely remove ccp:

```sh
ccp uninstall
```

This deletes `~/.local/share/cc-provider`, removes the ccp line from `~/.zshrc`, and clears the current shell's provider env vars.

To reinstall (e.g. after pulling a new version):

```sh
# 1. Remove the old installation
ccp uninstall

# 2. Re-run the installer from the repo
bash install.sh

# 3. Reload your shell
source ~/.zshrc
```

> Your `providers.conf` is deleted during uninstall. Back it up first if you want to keep your profiles.

## Notes

- If `~/.claude/settings.json` has an `env` block with the same variables, it overrides shell env vars. `ccp doctor` detects this conflict.
- zsh only.
- Requires python3 (pre-installed on macOS).
