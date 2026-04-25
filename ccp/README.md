# ccp v0.0.1 — Claude Code 多 Provider 切换器

zsh 下的 Claude Code LLM Provider 快速切换工具。不同终端可以同时使用不同的 Provider，互不影响。支持 VS Code Claude Code 插件配置同步。

## 功能

- **多 Provider 切换** — 通过 shell 环境变量控制 Claude Code 的 LLM 后端，终端间隔离
- **VS Code 同步** — 将选定的 Provider 配置写入 VS Code `settings.json`，插件免登录使用
- **自动 Onboarding** — 跳过 Claude Code 的 OAuth 登录提示
- **配置诊断** — 检测环境冲突、VS Code 配置状态等

## 安装

```sh
git clone https://github.com/ximenchuifeng/ccp.git && cd ccp
bash install.sh
```

在 `~/.zshrc` 中添加：

```sh
ccp() { source "$HOME/.local/share/cc-provider/cc-provider.sh" "$@"; }
```

重新加载：

```sh
source ~/.zshrc
```

## 配置

编辑 `~/.local/share/cc-provider/providers.conf`：

```ini
[profile://glm]
name         = GLM-5.1
base_url     = https://open.bigmodel.cn/api/anthropic
auth_token   = ${ENV:GLM_API_KEY}
model        = glm-5.1
haiku_model  = glm-5.1
sonnet_model = glm-5.1
opus_model   = glm-5.1

[profile://kimi]
name         = Kimi
base_url     = https://api.kimi.com/coding/
auth_token   = ${ENV:KIMI_API_KEY}
model        = kimi-k2.5

[profile://openrouter]
name         = OpenRouter
base_url     = https://openrouter.ai/api
api_key      = ${ENV:OPENROUTER_API_KEY}
model        = claude-sonnet-4-6
```

密钥可以明文写在配置中，也可以用 `${ENV:环境变量名}` 从环境变量读取（推荐）。

## 支持的环境变量

| 配置字段 | 环境变量 | 说明 |
|---------|---------|------|
| `base_url` | `ANTHROPIC_BASE_URL` | API 地址 |
| `api_key` | `ANTHROPIC_API_KEY` | API 密钥 |
| `auth_token` | `ANTHROPIC_AUTH_TOKEN` | 认证 Token |
| `model` | `ANTHROPIC_MODEL` | 默认模型 |
| `haiku_model` | `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Haiku 模型 |
| `sonnet_model` | `ANTHROPIC_DEFAULT_SONNET_MODEL` | Sonnet 模型 |
| `opus_model` | `ANTHROPIC_DEFAULT_OPUS_MODEL` | Opus 模型 |

## 用法

```sh
ccp glm           # 切换到 glm 并启动 Claude Code
ccp                # 交互菜单选择 provider，然后启动 Claude Code
ccp use kimi       # 只切换环境变量，不启动 Claude Code
ccp sync-vscode    # 交互选择 provider，同步到 VS Code
ccp sync-vscode glm # 直接同步 glm 到 VS Code
ccp status         # 查看当前 provider 状态
ccp list           # 列出所有已配置的 profile
ccp edit           # 用编辑器打开配置文件
ccp doctor         # 诊断配置冲突（含 VS Code 插件状态）
ccp reset          # 重置为 Anthropic 官方（同时清空 VS Code 配置）
ccp uninstall      # 卸载 ccp
```

## VS Code 插件支持

`ccp sync-vscode` 会将选定 Provider 的环境变量写入 VS Code `settings.json` 的 `claudeCode.environmentVariables`，同时自动启用：

- `claudeCode.disableLoginPrompt: true`
- `claudeCode.hideOnboarding: true`

`ccp use <name>` 切换终端 Provider 时也会自动同步到 VS Code。

## 注意事项

- 如果 `~/.claude/settings.json` 的 `env` 字段中设置了相同的环境变量，会覆盖 shell 中的值。`ccp doctor` 会检测此冲突
- 仅支持 zsh
- 需要 python3（macOS 自带）
