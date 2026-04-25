# CCP - Claude Code Provider Switcher

## 项目概述

ccp 是一个 zsh 下的 Claude Code LLM Provider 切换工具。通过设置 shell 环境变量来控制 Claude Code 连接的 LLM 后端，支持多个终端同时使用不同的 Provider。

## 文件结构

- `cc-provider.sh` — 主脚本，包含配置解析、provider 切换、交互菜单等逻辑
- `providers.conf.example` — 配置文件模板，安装时复制到 `~/.local/share/cc-provider/providers.conf`
- `install.sh` — 安装脚本，将文件部署到 `~/.local/share/cc-provider/`
- `README.md` — 用户文档

## 核心机制

- 使用 `source` 方式加载（非直接执行），这样才能在当前 shell 中 `export` 环境变量
- zsh 中 `.zshrc` 通过函数包装调用：`ccp() { source "cc-provider.sh" "$@"; }`
- 配置解析使用 glob 模式匹配 `[profile://xxx]` section（zsh 的 `=~` 正则对 `[` 转义有兼容性问题）
- 序列化分隔符使用 `\x1f`（ASCII Unit Separator），避免与 URL、token 等值冲突
- `local` 声明必须在 while 循环外完成，zsh 中循环内重复 `local` 会回显变量值到 stdout

## 支持的环境变量

配置字段到环境变量的映射定义在 `_CCP_FIELDS` 和 `_CCP_ENVVARS` 数组中，新增字段只需同时更新这两个数组。

| 配置字段 | 环境变量 |
|---------|---------|
| `base_url` | `ANTHROPIC_BASE_URL` |
| `api_key` | `ANTHROPIC_API_KEY` |
| `auth_token` | `ANTHROPIC_AUTH_TOKEN` |
| `model` | `ANTHROPIC_MODEL` |
| `haiku_model` | `ANTHROPIC_DEFAULT_HAIKU_MODEL` |
| `sonnet_model` | `ANTHROPIC_DEFAULT_SONNET_MODEL` |
| `opus_model` | `ANTHROPIC_DEFAULT_OPUS_MODEL` |

## Onboarding / Login 跳过机制

Claude Code 在启动时会检查 `~/.claude.json`（注意不是 `settings.json`）中的 `hasCompletedOnboarding` 字段。如果为 `false` 或不存在，会强制进入 OAuth login 流程。

ccp 在 `_ccp_switch()` 中自动调用 `_ccp_ensure_onboarding()`，使用 python3（macOS 自带）安全地将 `hasCompletedOnboarding` 设为 `true`，从而跳过 login 提示。

**注意**：网上流传的 `CLAUDE_CODE_SKIP_AUTH_LOGIN` 和 `disableLoginPrompt` 环境变量/设置项**不存在**，是伪造信息。唯一有效的跳过方式是 `~/.claude.json` 中的 `hasCompletedOnboarding: true`。

## VS Code 插件环境变量同步

VS Code Claude Code 插件通过 `settings.json` 中的 `claudeCode.environmentVariables` 读取环境变量。ccp 在 `_ccp_switch()` 中自动调用 `_ccp_sync_vscode()`，将当前 provider 的 `ANTHROPIC_*` 环境变量写入 VS Code `settings.json`（路径：`~/Library/Application Support/Code/User/settings.json`）。

同时会自动设置 `claudeCode.disableLoginPrompt: true` 和 `claudeCode.hideOnboarding: true`。

也可通过 `ccp sync-vscode` 手动触发同步。`ccp doctor` 第 5 项会检测 VS Code 配置是否与当前 provider 一致。`ccp reset` 会清空 VS Code 的 `claudeCode.environmentVariables`。

## 已知坑

1. **`~/.claude/settings.json` 的 `env` 字段会覆盖 shell 环境变量** — 使用 ccp 时需清空 settings.json 中的 env 块
2. **zsh `local` 在循环内的回显问题** — `local key value` 在 `while read` 循环内会输出 `key=xxx\nvalue=xxx` 到 stdout，必须在循环外声明
3. **zsh 正则对 `[` 的处理** — `[[ "$line" =~ '^\[profile://' ]]` 在默认 POSIX ERE 模式下匹配失败，改用 glob `[[ "$line" = \[profile://* ]]`
4. **`~/.claude.json` vs `~/.claude/settings.json`** — 前者是应用状态文件（存 `hasCompletedOnboarding` 等），后者是用户设置文件（存权限、插件等）。两者不能混用
