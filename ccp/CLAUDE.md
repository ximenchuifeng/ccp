# CCP v0.0.1 — Claude Code Provider Switcher

## 项目概述

ccp 是一个 zsh 下的 Claude Code LLM Provider 切换工具。通过 shell 环境变量控制 Claude Code 连接的 LLM 后端，支持多个终端同时使用不同的 Provider。同时支持将 Provider 配置同步到 VS Code Claude Code 插件。

## 文件结构

- `cc-provider.sh` — 主脚本（source 加载，非直接执行）
- `providers.conf.example` — 配置模板，安装时复制到 `~/.local/share/cc-provider/providers.conf`
- `install.sh` — 安装脚本
- `CLAUDE.md` — 开发文档（本文件）
- `README.md` — 用户文档（英文）
- `README.zh-CN.md` — 用户文档（中文）

## 核心机制

- **source 加载**: `.zshrc` 中通过 `ccp() { source "cc-provider.sh" "$@"; }` 包装调用，这样 export 的环境变量才生效于当前 shell
- **配置解析**: glob 模式匹配 `[profile://xxx]` section（zsh 的 `=~` 正则对 `[` 转义有兼容性问题）
- **序列化**: `\x1f`（ASCII Unit Separator）分隔字段，避免与 URL、token 冲突
- **zsh local 坑**: `local` 声明必须在 while 循环外完成，循环内重复 `local` 会回显变量值到 stdout

## 配置字段 → 环境变量映射

定义在 `_CCP_FIELDS` 和 `_CCP_ENVVARS` 两个数组中，新增字段只需同时更新。

| # | 配置字段 | 环境变量 |
|---|---------|---------|
| 1 | `name` | *(仅显示)* |
| 2 | `base_url` | `ANTHROPIC_BASE_URL` |
| 3 | `api_key` | `ANTHROPIC_API_KEY` |
| 4 | `auth_token` | `ANTHROPIC_AUTH_TOKEN` |
| 5 | `model` | `ANTHROPIC_MODEL` |
| 6 | `haiku_model` | `ANTHROPIC_DEFAULT_HAIKU_MODEL` |
| 7 | `sonnet_model` | `ANTHROPIC_DEFAULT_SONNET_MODEL` |
| 8 | `opus_model` | `ANTHROPIC_DEFAULT_OPUS_MODEL` |

密钥支持 `${ENV:环境变量名}` 语法从 shell 环境读取。

## 功能模块

### 1. Provider 切换 (`_ccp_switch`)
1. 检测 `~/.claude/settings.json` 中 ANTHROPIC_* env 冲突，提示清除
2. `_ccp_parse_profile` 解析配置，export 环境变量
3. `_ccp_ensure_onboarding` 自动设置 `hasCompletedOnboarding: true`
4. `_ccp_sync_vscode` 自动同步到 VS Code settings.json

### 2. Onboarding 跳过 (`_ccp_ensure_onboarding`)
修改 `~/.claude.json` 中的 `hasCompletedOnboarding` 为 `true`，跳过 OAuth login。优先用 python3（安全），fallback 用 sed。

### 3. VS Code 插件同步 (`_ccp_sync_vscode` / `_ccp_write_vscode`)
- 将指定 provider 的配置写入 VS Code `settings.json` 的 `claudeCode.environmentVariables` 数组
- 同时设置 `claudeCode.disableLoginPrompt: true` 和 `claudeCode.hideOnboarding: true`
- `ccp sync-vscode` 无参数时弹出交互选择菜单，有参数时直接指定 provider
- `ccp reset` 时调用 `_ccp_clear_vscode_env` 清空

### 4. 全局冲突检测 (`_ccp_has_global_conflict` / `_ccp_clean_global_env`)
检测并清除 `~/.claude/settings.json` 中的 `env` 块（旧版 cc-switch 等工具写入的配置）。

### 5. 诊断 (`_ccp_doctor`)
5 项检查：
1. `~/.claude/settings.json` 冲突
2. 当前 shell 环境变量
3. 已配置 profiles
4. `~/.claude.json` onboarding 状态
5. VS Code settings.json provider 配置

### 6. 卸载 (`_ccp_uninstall`)
删除安装目录、从 `.zshrc` 移除 ccp 行、unset 环境变量。

## 已知坑

1. `~/.claude/settings.json` 的 `env` 字段会覆盖 shell 环境变量 — 使用 ccp 时需清空
2. zsh `local` 在 `while read` 循环内会输出变量值到 stdout，必须在循环外声明
3. zsh `[[ =~ ]]` 对 `[` 的处理有兼容性问题，改用 glob `[[ = \[profile://* ]]`
4. `~/.claude.json`（应用状态）vs `~/.claude/settings.json`（用户设置）— 两者不能混用
5. 网传的 `CLAUDE_CODE_SKIP_AUTH_LOGIN` 和 `disableLoginPrompt` 环境变量**不存在**，是伪造信息
