#!/bin/bash

# ByteFlow 启动脚本
# 用于启动网络流量监控采集器和 Web 服务器

set -e

echo "========================================="
echo "      ByteFlow - 网络流量监控系统"
echo "========================================="
echo ""

# 检查是否在 macOS 上运行
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "错误: ByteFlow 只能在 macOS 系统上运行"
    echo "当前系统: $OSTYPE"
    exit 1
fi

# 检查 Python 3
if ! command -v python3 &> /dev/null; then
    echo "错误: 未找到 Python 3"
    echo "请安装 Python 3.8 或更高版本"
    exit 1
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
echo "检测到 Python 版本: $PYTHON_VERSION"

# 检查虚拟环境
if [ ! -d "venv" ]; then
    echo "创建 Python 虚拟环境..."
    python3 -m venv venv
    echo "✓ 虚拟环境已创建"
fi

# 激活虚拟环境
source venv/bin/activate

# 安装依赖
echo ""
echo "检查并安装依赖包..."
pip install -q --upgrade pip
pip install -q -r requirements.txt
echo "✓ 依赖安装完成"

# 检查 nettop 命令
if ! command -v nettop &> /dev/null; then
    echo ""
    echo "警告: 未找到 nettop 命令"
    echo "nettop 是 macOS 自带工具，通常位于 /usr/bin/nettop"
fi

echo ""
echo "========================================="
echo "启动 ByteFlow 服务..."
echo "========================================="
echo ""

# 创建 PID 文件目录
mkdir -p .pids

# 启动采集器
echo "1. 启动网络流量采集器..."
python3 collector.py &
COLLECTOR_PID=$!
echo $COLLECTOR_PID > .pids/collector.pid
echo "   采集器进程 PID: $COLLECTOR_PID"
sleep 2

# 启动 API 服务器
echo ""
echo "2. 启动 Web API 服务器..."
python3 api.py &
API_PID=$!
echo $API_PID > .pids/api.pid
echo "   API 服务器进程 PID: $API_PID"

echo ""
echo "========================================="
echo "✓ ByteFlow 已成功启动！"
echo "========================================="
echo ""
echo "Web 界面地址: http://127.0.0.1:8787"
echo "数据库位置: $(pwd)/byteflow.db"
echo ""
echo "提示:"
echo "  • 首次运行时，系统可能会请求权限，请允许访问"
echo "  • 采集器每秒采样一次网络流量"
echo "  • 数据会自动保存到 SQLite 数据库"
echo "  • 使用 ./stop.sh 停止服务"
echo ""
echo "正在运行中... (按 Ctrl+C 停止)"
echo ""

# 等待用户中断
wait
