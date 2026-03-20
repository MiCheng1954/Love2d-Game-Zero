#!/usr/bin/env bash
# tests/run.sh
# 一键运行所有单元测试
# 用法：bash tests/run.sh
# 依赖：busted（luarocks install busted）

set -e
cd "$(dirname "$0")/.."   # 切换到项目根目录

echo "================================================"
echo "  Zero — Unit Tests"
echo "================================================"

# 检查 busted 是否可用
if ! command -v busted &>/dev/null; then
    echo "[ERROR] busted 未安装，请运行："
    echo "  luarocks install busted"
    exit 1
fi

busted \
    --config-file=tests/.busted \
    --output=TAP \
    tests/

echo "================================================"
echo "  All tests done."
echo "================================================"
