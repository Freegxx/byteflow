#!/bin/bash

# ByteFlow 停止脚本

echo "正在停止 ByteFlow 服务..."

# 停止采集器
if [ -f .pids/collector.pid ]; then
    COLLECTOR_PID=$(cat .pids/collector.pid)
    if ps -p $COLLECTOR_PID > /dev/null 2>&1; then
        echo "停止采集器进程 (PID: $COLLECTOR_PID)..."
        kill $COLLECTOR_PID
        rm .pids/collector.pid
    fi
fi

# 停止 API 服务器
if [ -f .pids/api.pid ]; then
    API_PID=$(cat .pids/api.pid)
    if ps -p $API_PID > /dev/null 2>&1; then
        echo "停止 API 服务器进程 (PID: $API_PID)..."
        kill $API_PID
        rm .pids/api.pid
    fi
fi

# 清理
if [ -d .pids ] && [ -z "$(ls -A .pids)" ]; then
    rmdir .pids
fi

echo "✓ ByteFlow 已停止"
