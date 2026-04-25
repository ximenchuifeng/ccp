############################################################
# cc-provider: 多 Provider 切换器 (zsh compatible)
#
# 原理：环境变量 per-shell 隔离，不同终端互不影响
#
# 用法：ccp [命令] [参数]
############################################################

PROVIDER_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/cc-provider"
CONFIG_FILE="$PROVIDER_DIR/providers.conf"
_CLAUDE_SETTINGS="$HOME/.claude/settings.json"
_CLAUDE_JSON="$HOME/.claude.json"
_CLAUDE_VSCODE_CONFIG="$HOME/.claude/config.json"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

############################################################
# 配置解析
############################################################

# 序列化分隔符 (ASCII Unit Separator, 不会出现在正常值中)
_SEP=$'\x1f'

# 支持的配置字段 → 环境变量映射
_CCP_FIELDS=(name base_url api_key auth_token model haiku_model sonnet_model opus_model)
_CCP_ENVVARS=('' ANTHROPIC_BASE_URL ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL)

# 列出所有 profile 名称
_ccp_list_profiles() {
    grep '^\[profile://' "$CONFIG_FILE" 2>/dev/null | sed 's/\[profile:\/\///;s/\]//' || true
}

# 解析 ${ENV:VAR_NAME} → 从环境变量读取
_ccp_resolve_env() {
    local value="$1"
    if [[ "$value" =~ ^\$\{ENV:([^}]+)\}$ ]]; then
        local env_var="${match[1]}"
        value="${(P)env_var:-}"
        if [[ -z "$value" ]]; then
            echo "ERROR: \$$env_var not set" >&2; return 1
        fi
    fi
    echo "$value"
}

# 解析指定 profile，输出: 8 个字段用 \x1f 分隔
_ccp_parse_profile() {
    local profile_name="$1"
    local key="" value="" in_section=false sec_name=""
    local -A fields
    for f in "${_CCP_FIELDS[@]}"; do fields[$f]=""; done

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        if [[ "$line" = \[profile://* ]]; then
            in_section=false
            sec_name="${line#\[profile://}"
            sec_name="${sec_name%\]}"
            [[ "$sec_name" == "$profile_name" ]] && in_section=true
            continue
        fi

        if $in_section; then
            key=$(echo "$line" | cut -d'=' -f1 | tr -d ' ')
            value=$(echo "$line" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            for f in "${_CCP_FIELDS[@]}"; do
                [[ "$key" == "$f" ]] && fields[$f]="$value"
            done
        fi
    done < "$CONFIG_FILE"

    # 解析密钥类字段的环境变量引用
    local sf=""
    for sf in api_key auth_token; do
        if [[ -n "${fields[$sf]}" ]]; then
            local resolved=""
            resolved=$(_ccp_resolve_env "${fields[$sf]}") || return 1
            fields[$sf]="$resolved"
        fi
    done

    # 输出: field1\x1ffield2\x1f...
    local result=""
    for f in "${_CCP_FIELDS[@]}"; do
        result="${result}${_SEP}${fields[$f]}"
    done
    echo "${result#$_SEP}"
}

############################################################
# Onboarding 状态管理（跳过 login 提示）
############################################################

# 确保 ~/.claude.json 中 hasCompletedOnboarding = true
# 使用第三方 provider 时，Claude Code 仍可能要求 OAuth login，
# 设置此字段可以跳过 onboarding/login 流程
_ccp_ensure_onboarding() {
    if [[ ! -f "$_CLAUDE_JSON" ]]; then
        echo '{}' > "$_CLAUDE_JSON"
    fi

    # 用 python3 安全修改 JSON（macOS 自带）
    if command -v python3 &>/dev/null; then
        python3 -c "
import json, sys
try:
    with open('$_CLAUDE_JSON', 'r') as f:
        d = json.load(f)
    if d.get('hasCompletedOnboarding'):
        sys.exit(0)
    d['hasCompletedOnboarding'] = True
    with open('$_CLAUDE_JSON', 'w') as f:
        json.dump(d, f, indent=2)
except Exception as e:
    print(f'Warning: failed to set hasCompletedOnboarding: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            return 0
        fi
    fi

    # fallback: 没有 python3 时用 sed（不完美但可用）
    if grep -q '"hasCompletedOnboarding"' "$_CLAUDE_JSON" 2>/dev/null; then
        sed -i.bak 's/"hasCompletedOnboarding":[[:space:]]*false/"hasCompletedOnboarding": true/' "$_CLAUDE_JSON" 2>/dev/null
        rm -f "${_CLAUDE_JSON}.bak"
    else
        # 在第一个 { 后插入
        sed -i.bak '2i\
  "hasCompletedOnboarding": true,
' "$_CLAUDE_JSON" 2>/dev/null
        rm -f "${_CLAUDE_JSON}.bak"
    fi
}

############################################################
# VS Code 插件登录跳过（~/.claude/config.json）
############################################################

# 确保 ~/.claude/config.json 包含 primaryApiKey，跳过 VS Code 插件登录
_ccp_ensure_vscode_config() {
    # 目录不存在则创建
    [[ ! -d "$HOME/.claude" ]] && mkdir -p "$HOME/.claude"

    if [[ -f "$_CLAUDE_VSCODE_CONFIG" ]]; then
        # 文件已存在，检查是否有 primaryApiKey
        if grep -q '"primaryApiKey"' "$_CLAUDE_VSCODE_CONFIG" 2>/dev/null; then
            return 0
        fi
        # 已有文件但缺少 primaryApiKey，追加
        if command -v python3 &>/dev/null; then
            python3 -c "
import json
with open('$_CLAUDE_VSCODE_CONFIG', 'r') as f:
    d = json.load(f)
d['primaryApiKey'] = 'ccp-bypass'
with open('$_CLAUDE_VSCODE_CONFIG', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null && return 0
        fi
    fi

    # 文件不存在或 python3 fallback 失败，直接创建
    echo '{"primaryApiKey":"ccp-bypass"}' > "$_CLAUDE_VSCODE_CONFIG"
}

############################################################
# 全局配置冲突检测与清理（纯 zsh + awk + sed）
############################################################

# 检测 settings.json 中是否有 ANTHROPIC_* env 配置
_ccp_has_global_conflict() {
    [[ ! -f "$_CLAUDE_SETTINGS" ]] && return 1
    grep -q '"ANTHROPIC_' "$_CLAUDE_SETTINGS" 2>/dev/null
}

# 清除 settings.json 中的 env 字段（删除整个 env 块）
_ccp_clean_global_env() {
    [[ ! -f "$_CLAUDE_SETTINGS" ]] && return 0
    cp "$_CLAUDE_SETTINGS" "${_CLAUDE_SETTINGS}.ccp-backup"

    # awk 状态机：跳过从 "env" 开始到花括号平衡的整个块
    awk '
    /"env"[[:space:]]*:/ { skip=1; depth=0 }
    skip {
        for (i=1; i<=length($0); i++) {
            c = substr($0, i, 1)
            if (c == "{") depth++
            if (c == "}") depth--
        }
        if (depth <= 0) { skip=0 }
        next
    }
    !skip { print }
    ' "${_CLAUDE_SETTINGS}.ccp-backup" > "$_CLAUDE_SETTINGS"

    # 清理 } 前一行的尾随逗号（env 被删后可能残留）
    local tmpfile
    tmpfile=$(mktemp)
    awk '
    NR > 1 { prev = lines[NR-1]; delete lines[NR-1] }
    /^[[:space:]]*\}/ && prev ~ /,[[:space:]]*$/ {
        sub(/,[[:space:]]*$/, "", prev)
    }
    { lines[NR] = $0; if (NR > 1) print prev }
    END { if (lines[NR]) print lines[NR] }
    ' "$_CLAUDE_SETTINGS" > "$tmpfile" && mv "$tmpfile" "$_CLAUDE_SETTINGS"
}

# 非阻塞诊断：每次 ccp 命令入口调用
_ccp_diagnose() {
    _ccp_has_global_conflict || return 0
    echo -e "${YELLOW}Warning: ${_CLAUDE_SETTINGS} has ANTHROPIC_* env — ccp may be overridden.${NC}" >&2
    echo -e "${YELLOW}  Run ${BOLD}ccp doctor${NC} for details, or use ${BOLD}ccp reset${NC} to resolve.${NC}" >&2
}

# 检测 VS Code 插件 config.json 是否就绪
_ccp_vscode_config_ok() {
    [[ -f "$_CLAUDE_VSCODE_CONFIG" ]] && grep -q '"primaryApiKey"' "$_CLAUDE_VSCODE_CONFIG" 2>/dev/null
}

# 详细诊断命令
_ccp_doctor() {
    echo -e "${BOLD}${CYAN}=== ccp Doctor ===${NC}" >&2
    echo "" >&2

    # 1. settings.json 冲突检查
    echo -e "${BOLD}1. Global config (${_CLAUDE_SETTINGS})${NC}" >&2
    if _ccp_has_global_conflict; then
        echo -e "   ${RED}CONFLICT: ANTHROPIC_* env vars found in settings.json${NC}" >&2
        echo -e "   This will override ccp shell env vars. Contents:" >&2
        grep '"ANTHROPIC_' "$_CLAUDE_SETTINGS" 2>/dev/null | while IFS= read -r line; do
            echo -e "     ${YELLOW}${line}${NC}" >&2
        done
        echo -e "   Fix: ${BOLD}ccp reset${NC} or ${BOLD}ccp use <name>${NC} (will prompt to clear)" >&2
    else
        if [[ -f "$_CLAUDE_SETTINGS" ]]; then
            echo -e "   ${GREEN}OK — no ANTHROPIC env conflicts${NC}" >&2
        else
            echo -e "   ${GREEN}OK — settings.json not found (clean state)${NC}" >&2
        fi
    fi

    echo "" >&2
    echo -e "${BOLD}2. Shell env vars (PID: $$)${NC}" >&2
    _ccp_status

    echo "" >&2
    echo -e "${BOLD}3. Profiles${NC}" >&2
    if [[ -f "$CONFIG_FILE" ]]; then
        _ccp_list
    else
        echo -e "   ${YELLOW}No config file: $CONFIG_FILE${NC}" >&2
    fi

    echo "" >&2
    echo -e "${BOLD}4. Onboarding (${_CLAUDE_JSON})${NC}" >&2
    if [[ -f "$_CLAUDE_JSON" ]]; then
        if grep -q '"hasCompletedOnboarding"[[:space:]]*:[[:space:]]*true' "$_CLAUDE_JSON" 2>/dev/null; then
            echo -e "   ${GREEN}OK — hasCompletedOnboarding: true${NC}" >&2
        else
            echo -e "   ${RED}MISSING — hasCompletedOnboarding not set to true${NC}" >&2
            echo -e "   This may cause login prompts when using third-party providers." >&2
            echo -e "   Fix: ${BOLD}ccp use <name>${NC} will auto-set it, or run ${BOLD}ccp doctor --fix${NC}" >&2
        fi
    else
        echo -e "   ${YELLOW}Not found — will be created on first ccp switch${NC}" >&2
    fi

    echo "" >&2
    echo -e "${BOLD}5. VS Code plugin (${_CLAUDE_VSCODE_CONFIG})${NC}" >&2
    if _ccp_vscode_config_ok; then
        echo -e "   ${GREEN}OK — primaryApiKey set (VS Code login bypassed)${NC}" >&2
    else
        echo -e "   ${RED}MISSING — ~/.claude/config.json missing primaryApiKey${NC}" >&2
        echo -e "   VS Code Claude plugin may prompt for login." >&2
        echo -e "   Fix: ${BOLD}ccp use <name>${NC} will auto-create it, or run ${BOLD}ccp fix-vscode${NC}" >&2
    fi
}

############################################################
# 核心操作（直接修改当前 shell 环境）
############################################################

_ccp_switch() {
    local profile_name="$1"

    # 检测 settings.json 冲突，提示清除
    if _ccp_has_global_conflict; then
        echo -e "${YELLOW}settings.json has ANTHROPIC env config (e.g. cc-switch).${NC}" >&2
        echo -e "${YELLOW}This will override ccp. Clear it? [Y/n]${NC}" >&2
        printf "   > " >&2
        local clear_confirm=""
        read -r clear_confirm </dev/tty
        if [[ "$clear_confirm" =~ ^[nN]$ ]]; then
            echo -e "${YELLOW}Skipping clear. ccp may be overridden by settings.json.${NC}" >&2
        else
            _ccp_clean_global_env
            echo -e "${GREEN}Cleared ANTHROPIC env from settings.json${NC}" >&2
        fi
    fi

    local parsed=""
    parsed=$(_ccp_parse_profile "$profile_name") || return 1

    # 拆分到数组
    local -a vals
    IFS="$_SEP" read -rA vals <<< "$parsed"

    local name="${vals[1]}" base_url="${vals[2]}"
    local api_key="${vals[3]}" auth_token="${vals[4]}"

    if [[ -z "$base_url" ]]; then
        echo -e "${RED}Error: '$profile_name' missing base_url${NC}" >&2
        return 1
    fi
    if [[ -z "$api_key" && -z "$auth_token" ]]; then
        echo -e "${RED}Error: '$profile_name' missing api_key or auth_token${NC}" >&2
        return 1
    fi

    # 导出所有非空字段
    local i=1 envvar="" val=""
    for f in "${_CCP_FIELDS[@]}"; do
        envvar="${_CCP_ENVVARS[$i]}"
        val="${vals[$i]}"
        ((i++))
        [[ -z "$envvar" || -z "$val" ]] && continue
        export "$envvar"="$val"
    done

    # 确保 onboarding 已完成，跳过 login 提示
    _ccp_ensure_onboarding

    # 确保 VS Code 插件 config.json 存在，跳过 VS Code 登录
    _ccp_ensure_vscode_config

    echo -e "${GREEN}Switched to: ${BOLD}$name${NC} | $base_url | ${vals[5]:-default}" >&2
}

_ccp_reset() {
    local envvar=""
    for envvar in "${_CCP_ENVVARS[@]}"; do
        [[ -n "$envvar" ]] && unset "$envvar" 2>/dev/null
    done
    echo -e "${GREEN}Shell env vars cleared (Anthropic Official).${NC}" >&2

    # 提示是否恢复 cc-switch 兼容状态
    if _ccp_has_global_conflict; then
        echo "" >&2
        echo -e "${YELLOW}settings.json still has ANTHROPIC env config.${NC}" >&2
        echo -e "${YELLOW}Clear it too? (required for cc-switch to work cleanly) [y/N]${NC}" >&2
        printf "   > " >&2
        local reset_confirm=""
        read -r reset_confirm </dev/tty
        if [[ "$reset_confirm" =~ ^[yY]$ ]]; then
            _ccp_clean_global_env
            echo -e "${GREEN}Cleared. settings.json is now clean for cc-switch.${NC}" >&2
        else
            echo -e "${YELLOW}Kept settings.json as-is. cc-switch config preserved.${NC}" >&2
        fi
    fi
}

_ccp_status() {
    echo -e "${BLUE}Provider Status (PID: $$)${NC}" >&2
    if [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
        echo -e "   Mode:     ${GREEN}Third-party${NC}" >&2
        echo -e "   URL:      ${ANTHROPIC_BASE_URL}" >&2
        echo -e "   Model:    ${ANTHROPIC_MODEL:-default}" >&2
        [[ -n "${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}" ]]  && echo -e "   Haiku:    ${ANTHROPIC_DEFAULT_HAIKU_MODEL}" >&2
        [[ -n "${ANTHROPIC_DEFAULT_SONNET_MODEL:-}" ]] && echo -e "   Sonnet:   ${ANTHROPIC_DEFAULT_SONNET_MODEL}" >&2
        [[ -n "${ANTHROPIC_DEFAULT_OPUS_MODEL:-}" ]]   && echo -e "   Opus:     ${ANTHROPIC_DEFAULT_OPUS_MODEL}" >&2
        local k="${ANTHROPIC_API_KEY:-}"
        [[ -n "$k" ]] && echo -e "   API Key:  ****${k: -4}" >&2
        local t="${ANTHROPIC_AUTH_TOKEN:-}"
        [[ -n "$t" ]] && echo -e "   Auth Token: ****${t: -4}" >&2
    else
        echo -e "   Mode:     ${YELLOW}Anthropic Official${NC}" >&2
    fi
}

_ccp_list() {
    echo -e "${BLUE}Configured Profiles:${NC}" >&2
    local i=1 p="" parsed="" pname="" purl="" pmodel=""
    local -a vals
    local profiles=""
    profiles=$(_ccp_list_profiles)
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        parsed=$(_ccp_parse_profile "$p") || continue
        IFS="$_SEP" read -rA vals <<< "$parsed"
        echo -e "   ${BOLD}$i)${NC} ${GREEN}${vals[1]}${NC} ($p)" >&2
        echo -e "      URL: ${vals[2]} | Model: ${vals[5]:-default}" >&2
        ((i++))
    done <<< "$profiles"
}

_ccp_interactive() {
    local profiles=""
    profiles=$(_ccp_list_profiles)
    if [[ -z "$profiles" ]]; then
        echo -e "${RED}No profiles. Edit: $CONFIG_FILE${NC}" >&2
        return 1
    fi

    echo -e "${BOLD}${CYAN}=== Claude Code Provider Switcher ===${NC}" >&2
    echo -e "${CYAN}   Shell PID: $$ (each terminal is isolated)${NC}" >&2
    echo "" >&2

    local current_url="${ANTHROPIC_BASE_URL:-}"
    if [[ -n "$current_url" ]]; then
        echo -e "   Current: ${GREEN}$current_url${NC}" >&2
    else
        echo -e "   Current: ${YELLOW}Anthropic Official${NC}" >&2
    fi
    echo "" >&2

    local count=0 p="" parsed="" pname="" purl="" marker="" choice=""
    local -a pnames vals
    echo -e "   ${BOLD}0)${NC} Reset (Anthropic Official)" >&2

    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        ((count++))
        parsed=$(_ccp_parse_profile "$p") || continue
        IFS="$_SEP" read -rA vals <<< "$parsed"
        pname="${vals[1]}" purl="${vals[2]}"
        marker=""
        [[ "$purl" == "$current_url" ]] && marker=" ${GREEN}<- current${NC}"
        echo -e "   ${BOLD}$count)${NC} $pname ($p)${marker}" >&2
        pnames+=("$p")
    done <<< "$profiles"

    echo "" >&2
    printf "   ${BOLD}Select [0-%s]: ${NC}" "$count" >&2

    read -r choice </dev/tty

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -gt "$count" ]]; then
        echo -e "${RED}Invalid choice${NC}" >&2
        return 1
    fi

    if [[ "$choice" -eq 0 ]]; then
        _ccp_reset
    else
        _ccp_switch "${pnames[$choice]}"
    fi
}

############################################################
# 卸载
############################################################

_ccp_uninstall() {
    echo -e "${YELLOW}This will remove ccp completely:${NC}" >&2
    echo -e "  - Delete ${PROVIDER_DIR}" >&2
    echo -e "  - Remove ccp line from ~/.zshrc" >&2
    echo -e "  - Unset ANTHROPIC_* env vars in current shell" >&2
    echo "" >&2
    printf "   ${BOLD}Continue? [y/N]: ${NC}" >&2
    local confirm=""
    read -r confirm </dev/tty
    [[ ! "$confirm" =~ ^[yY]$ ]] && { echo -e "${RED}Cancelled.${NC}" >&2; return 0; }

    # 1. 从 .zshrc 删除 ccp 行
    if [[ -f "$HOME/.zshrc" ]] && grep -q 'cc-provider.sh' "$HOME/.zshrc" 2>/dev/null; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.ccp-backup"
        local tmpfile
        tmpfile=$(mktemp)
        grep -v 'cc-provider.sh' "$HOME/.zshrc" > "$tmpfile"
        mv "$tmpfile" "$HOME/.zshrc"
        echo -e "${GREEN}Removed ccp from ~/.zshrc${NC} (backup: ~/.zshrc.ccp-backup)" >&2
    else
        echo -e "${YELLOW}No ccp line found in ~/.zshrc${NC}" >&2
    fi

    # 2. 删除安装目录
    if [[ -d "$PROVIDER_DIR" ]]; then
        rm -rf "$PROVIDER_DIR"
        echo -e "${GREEN}Deleted ${PROVIDER_DIR}${NC}" >&2
    else
        echo -e "${YELLOW}${PROVIDER_DIR} not found${NC}" >&2
    fi

    # 3. 清理当前 shell 环境变量
    local envvar=""
    for envvar in "${_CCP_ENVVARS[@]}"; do
        [[ -n "$envvar" ]] && unset "$envvar" 2>/dev/null
    done
    echo -e "${GREEN}Unset ANTHROPIC_* env vars${NC}" >&2

    echo "" >&2
    echo -e "${GREEN}ccp uninstalled. Run ${BOLD}source ~/.zshrc${NC} or open a new terminal.${NC}" >&2
}

############################################################
# 入口
############################################################

_ccp_usage() {
    cat <<EOF >&2
${BOLD}ccp${NC} - Multi-provider switcher for Claude Code
Each terminal is isolated — different providers run simultaneously.

${BOLD}Usage:${NC}
   ccp              Interactive menu, then launch Claude Code
   ccp <name>       Switch to profile and launch Claude Code
   ccp use <name>   Switch to profile only (no launch)
   ccp reset        Reset to Anthropic Official
   ccp status       Show current status
   ccp list         List all profiles
   ccp edit         Edit configuration
   ccp doctor       Diagnose config conflicts
   ccp fix-vscode   Fix VS Code plugin login (create config.json)
   ccp uninstall    Remove ccp completely

${BOLD}Config:${NC} $CONFIG_FILE
EOF
}

case "${1:-}" in
    use)
        if [[ -z "${2:-}" ]]; then
            echo -e "${RED}Profile name required. Use 'ccp list' to see profiles.${NC}" >&2
            return 1
        fi
        _ccp_switch "$2"
        ;;
    reset)  _ccp_reset ;;
    status) _ccp_status ;;
    list|ls) _ccp_list ;;
    edit)       ${EDITOR:-vim} "$CONFIG_FILE" ;;
    doctor)     _ccp_doctor ;;
    fix-vscode)
        _ccp_ensure_vscode_config
        if _ccp_vscode_config_ok; then
            echo -e "${GREEN}VS Code config fixed: ${_CLAUDE_VSCODE_CONFIG}${NC}" >&2
        else
            echo -e "${RED}Failed to create VS Code config${NC}" >&2
            return 1
        fi
        ;;
    uninstall)  _ccp_uninstall ;;
    claude|"")
        _ccp_diagnose
        _ccp_interactive || return 1
        claude
        ;;
    --help|-h)
        _ccp_usage
        ;;
    *)
        _ccp_diagnose
        _ccp_switch "$1" || return 1
        claude
        ;;
esac
