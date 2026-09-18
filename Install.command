#!/bin/bash
# ByteFlow Installer for macOS
# ByteFlow macOS 安装脚本

set -e

INSTALL_DIR="$HOME/Applications/ByteFlow"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT_PLIST="com.byteflow.agent.plist"

echo "======================================"
echo "ByteFlow 安装向导"
echo "ByteFlow Installer"
echo "======================================"
echo ""

# 检查系统
if [[ "$(uname)" != "Darwin" ]]; then
    echo "错误: 此脚本仅支持 macOS"
    exit 1
fi

# 检查 Python 3
if ! command -v python3 &> /dev/null; then
    echo "错误: 未找到 Python 3"
    echo "请先安装 Python 3: https://www.python.org/downloads/"
    exit 1
fi

echo "✓ Python 3 已安装"

# 创建安装目录
echo ""
echo "创建安装目录: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# 复制文件
echo "复制应用文件..."
cp -r "$(dirname "$0")"/* "$INSTALL_DIR/" 2>/dev/null || true

# 安装Python依赖
echo ""
echo "安装 Python 依赖..."
cd "$INSTALL_DIR"
python3 -m pip install --user -r requirements.txt -q

# 安装菜单栏应用依赖
python3 -m pip install --user rumps -q

echo "✓ 依赖安装完成"

# 询问是否设置开机启动
echo ""
read -p "是否设置开机自动启动？(y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "配置开机启动..."
    mkdir -p "$LAUNCH_AGENT_DIR"
    
    cat > "$LAUNCH_AGENT_DIR/$LAUNCH_AGENT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.byteflow.agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/start.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>WorkingDirectory</key>
    <string>$INSTALL_DIR</string>
    <key>StandardOutPath</key>
    <string>$INSTALL_DIR/logs/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$INSTALL_DIR/logs/stderr.log</string>
</dict>
</plist>
EOF
    
    # 加载 LaunchAgent
    launchctl load "$LAUNCH_AGENT_DIR/$LAUNCH_AGENT_PLIST" 2>/dev/null || true
    
    echo "✓ 开机启动已配置"
fi

# 创建日志目录
mkdir -p "$INSTALL_DIR/logs"

# 创建桌面快捷方式
echo ""
echo "创建启动脚本..."
cat > "$INSTALL_DIR/ByteFlow.command" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
./start.sh
EOF
chmod +x "$INSTALL_DIR/ByteFlow.command"

echo ""
echo "======================================"
echo "✓ 安装完成!"
echo "======================================"
echo ""
echo "ByteFlow 已安装到: $INSTALL_DIR"
echo ""
echo "启动方式:"
echo "  1. 双击: $INSTALL_DIR/ByteFlow.command"
echo "  2. 终端: cd $INSTALL_DIR && ./start.sh"
echo ""
echo "访问地址: http://127.0.0.1:8787"
echo ""
echo "首次运行需要授予终端权限:"
echo "  系统偏好设置 > 安全性与隐私 > 隐私 > 完全磁盘访问"
echo "  添加: Terminal.app 或您使用的终端应用"
echo ""
echo "如遇到 Gatekeeper 提示，请:"
echo "  右键点击 ByteFlow.command > 打开"
echo "  或: 系统偏好设置 > 安全性与隐私 > 通用 > 仍要打开"
echo ""

# 询问是否立即启动
read -p "是否立即启动 ByteFlow？(y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$INSTALL_DIR"
    ./start.sh
    sleep 2
    open "http://127.0.0.1:8787"
fi
