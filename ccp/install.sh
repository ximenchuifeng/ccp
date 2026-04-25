#!/usr/bin/env bash
# ccp 安装脚本
set -e

INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/cc-provider"

echo "Installing ccp to $INSTALL_DIR..."

mkdir -p "$INSTALL_DIR"
cp cc-provider.sh "$INSTALL_DIR/cc-provider.sh"

if [[ -f "$INSTALL_DIR/providers.conf" ]]; then
    echo "Found existing providers.conf, skipping (edit with: ccp edit)"
else
    if [[ -f providers.conf.example ]]; then
        cp providers.conf.example "$INSTALL_DIR/providers.conf"
        echo "Created providers.conf from example — edit it with your keys: ccp edit"
    fi
fi

# 检查 .zshrc 是否已有 ccp 配置
if grep -q 'cc-provider.sh' "$HOME/.zshrc" 2>/dev/null; then
    echo ".zshrc already has ccp configured."
else
    echo ""
    echo "Add this line to your ~/.zshrc:"
    echo ""
    echo '  ccp() { source "$HOME/.local/share/cc-provider/cc-provider.sh" "$@"; }'
    echo ""
    echo "Then reload: source ~/.zshrc"
fi

echo ""
echo "Done. Usage:"
echo "  ccp list       - list profiles"
echo "  ccp <name>     - switch provider and launch Claude Code"
echo "  ccp edit       - edit configuration"
