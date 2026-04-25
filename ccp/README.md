# ccp — Claude Code 多 Provider 切换器

zsh 下的 Claude Code LLM Provider 快速切换工具。不同终端可以同时使用不同的 Provider，互不影响。

## 原理

通过 shell 环境变量控制 Claude Code 连接的 LLM 后端。环境变量 per-shell 隔离，终端 A 用 Kimi，终端 B 用 OpenRouter，互不干扰。

## 支持的环境变量

| 配置字段 | 环境变量 | 说明 |
|---------|---------|------|
| `base_url` | `ANTHROPIC_BASE_URL` | API 地址 |
| `api_key` | `ANTHROPIC_API_KEY` | API 密钥 |
| `auth_token` | `ANTHROPIC_AUTH_TOKEN` | 认证 Token（部分平台用这个） |
| `model` | `ANTHROPIC_MODEL` | 默认模型 |
| `haiku_model` | `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Haiku 模型 |
| `sonnet_model` | `ANTHROPIC_DEFAULT_SONNET_MODEL` | Sonnet 模型 |
| `opus_model` | `ANTHROPIC_DEFAULT_OPUS_MODEL` | Opus 模型 |

## 安装

```sh
git clone <repo> && cd ccp
bash install.sh
```

然后在 `~/.zshrc` 中添加：

```sh
ccp() { source "$HOME/.local/share/cc-provider/cc-provider.sh" "$@"; }
```

重新加载 shell：

```sh
source ~/.zshrc
```

## 配置

编辑 `~/.local/share/cc-provider/providers.conf`：

```ini
[profile://openrouter]
name         = OpenRouter
base_url     = https://openrouter.ai/api
api_key      = sk-or-xxxxx
model        = claude-sonnet-4-6
sonnet_model = claude-sonnet-4-6
haiku_model  = claude-haiku-4-5
opus_model   = claude-opus-4-6

[profile://kimi]
name         = Kimi
base_url     = https://api.kimi.com/coding/
auth_token   = ${ENV:KIMI_API_KEY}
model        = kimi-k2.5
```

密钥可以明文写在配置中，也可以用 `${ENV:环境变量名}` 从环境变量读取。

## 用法

```sh
ccp kimi        # 切换到 kimi 并启动 Claude Code
ccp              # 交互菜单选择 provider，然后启动 Claude Code
ccp use kimi     # 只切换环境变量，不启动 Claude Code
ccp status       # 查看当前 provider 状态
ccp list         # 列出所有已配置的 profile
ccp edit         # 用编辑器打开配置文件
ccp reset        # 重置为 Anthropic 官方（同时清空 VS Code 配置）
ccp doctor       # 诊断配置冲突（含 VS Code 插件同步状态）
ccp sync-vscode  # 手动同步当前 provider 到 VS Code settings.json
```

## 注意事项

- 如果 `~/.claude/settings.json` 的 `env` 字段中设置了相同的环境变量，会覆盖 shell 中的值。使用 ccp 时应清空 `settings.json` 中的 `env` 块。
- 仅支持 zsh。
