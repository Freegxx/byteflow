#!/bin/bash
# Build Portable ByteFlow.dmg with Bundled Python
# 构建包含 Python 运行时的便携式 ByteFlow DMG
# 
# 必须在 macOS 上运行
# 生成的 DMG 可在任何相同架构的 Mac 上离线安装，无需系统 Python 或 pip

set -e

echo "======================================"
echo "ByteFlow Portable DMG Builder"
echo "便携式 DMG 构建器"
echo "======================================"
echo ""

# 检查是否在 macOS 上
if [[ "$(uname)" != "Darwin" ]]; then
    echo "错误: 此脚本仅能在 macOS 上运行"
    exit 1
fi

# 检测架构
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    PYTHON_ARCH="arm64"
    DMG_ARCH="arm64"
elif [[ "$ARCH" == "x86_64" ]]; then
    PYTHON_ARCH="x86_64"
    DMG_ARCH="x86_64"
else
    echo "错误: 不支持的架构 $ARCH"
    exit 1
fi

echo "检测到架构: $ARCH"
echo ""

# 配置
APP_NAME="ByteFlow"
VERSION="2.0"
DMG_NAME="ByteFlow-v${VERSION}-${DMG_ARCH}.dmg"
TEMP_DMG="temp.dmg"
SOURCE_DIR="$(pwd)"
BUILD_DIR="$SOURCE_DIR/build_portable"
APP_BUNDLE="$BUILD_DIR/ByteFlow.app"
VOLUME_NAME="ByteFlow Installer"

# Python 配置 - 使用 Python 3.11（避免 pyobjc 3.9 问题）
PYTHON_VERSION="3.11.9"
PYTHON_BUILD_STANDALONE_VERSION="20240713"

# Python-build-standalone URLs
if [[ "$PYTHON_ARCH" == "arm64" ]]; then
    PYTHON_URL="https://github.com/indygreg/python-build-standalone/releases/download/${PYTHON_BUILD_STANDALONE_VERSION}/cpython-${PYTHON_VERSION}+${PYTHON_BUILD_STANDALONE_VERSION}-aarch64-apple-darwin-install_only.tar.gz"
else
    PYTHON_URL="https://github.com/indygreg/python-build-standalone/releases/download/${PYTHON_BUILD_STANDALONE_VERSION}/cpython-${PYTHON_VERSION}+${PYTHON_BUILD_STANDALONE_VERSION}-x86_64-apple-darwin-install_only.tar.gz"
fi

PYTHON_TARBALL="python-${PYTHON_VERSION}-${PYTHON_ARCH}.tar.gz"

echo "Python 配置:"
echo "  版本: ${PYTHON_VERSION}"
echo "  架构: ${PYTHON_ARCH}"
echo "  来源: python-build-standalone"
echo ""

# 清理旧的构建文件
echo "清理旧的构建文件..."
rm -rf "$BUILD_DIR"
rm -f "$DMG_NAME"
rm -f "$TEMP_DMG"

# 创建构建目录
echo "创建构建目录..."
mkdir -p "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/"{MacOS,Resources,Frameworks}

# 下载 Python（如果尚未下载）
if [ ! -f "$PYTHON_TARBALL" ]; then
    echo "下载 Python ${PYTHON_VERSION} for ${PYTHON_ARCH}..."
    echo "URL: $PYTHON_URL"
    curl -L -o "$PYTHON_TARBALL" "$PYTHON_URL"
    
    if [ $? -ne 0 ]; then
        echo "错误: Python 下载失败"
        rm -f "$PYTHON_TARBALL"
        exit 1
    fi
    echo "✓ Python 下载完成"
else
    echo "使用已缓存的 Python: $PYTHON_TARBALL"
fi

# 解压 Python 到 Frameworks
echo "解压 Python 到应用包..."
PYTHON_BUNDLE_DIR="$APP_BUNDLE/Contents/Frameworks/Python.framework"
mkdir -p "$PYTHON_BUNDLE_DIR"

tar -xzf "$PYTHON_TARBALL" -C "$PYTHON_BUNDLE_DIR" --strip-components=1

if [ $? -ne 0 ]; then
    echo "错误: Python 解压失败"
    exit 1
fi

# 验证 Python 可执行文件
BUNDLED_PYTHON="$PYTHON_BUNDLE_DIR/bin/python3"
if [ ! -f "$BUNDLED_PYTHON" ]; then
    echo "错误: 未找到 Python 可执行文件: $BUNDLED_PYTHON"
    exit 1
fi

echo "✓ Python 解压完成"
echo ""

# 测试 Python
echo "测试 bundled Python..."
"$BUNDLED_PYTHON" --version
echo ""

# 升级 pip
echo "升级 pip..."
"$BUNDLED_PYTHON" -m pip install --upgrade pip -q

# 安装依赖到 bundle
echo "安装 Python 依赖到应用包..."
echo "  - 核心依赖 (requirements.txt)"

# 创建临时 requirements 文件（固定版本以提高可靠性）
cat > "$BUILD_DIR/requirements_bundle.txt" <<EOF
fastapi==0.115.0
uvicorn==0.30.6
python-multipart==0.0.12
aiosqlite==0.20.0
pywebview==5.3
requests==2.32.3
EOF

"$BUNDLED_PYTHON" -m pip install -r "$BUILD_DIR/requirements_bundle.txt" -q

echo "  - 菜单栏依赖 (requirements-menubar.txt)"

# 为 Python 3.11 创建兼容的 menubar requirements
cat > "$BUILD_DIR/requirements_menubar_bundle.txt" <<EOF
pyobjc-core==10.3.1
pyobjc-framework-Cocoa==10.3.1
rumps==0.4.0
EOF

"$BUNDLED_PYTHON" -m pip install -r "$BUILD_DIR/requirements_menubar_bundle.txt" -q || {
    echo "警告: 菜单栏依赖安装失败（可选功能）"
}

echo "✓ 依赖安装完成"
echo ""

# 复制应用代码到 Resources
echo "复制应用代码到 Resources..."
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

cp *.py "$RESOURCES_DIR/" 2>/dev/null || true
cp *.json "$RESOURCES_DIR/" 2>/dev/null || true
cp *.md "$RESOURCES_DIR/" 2>/dev/null || true

# 复制 web 目录
if [ -d "web" ]; then
    cp -R web "$RESOURCES_DIR/"
fi

echo "✓ 应用代码复制完成"
echo ""

# 创建 Info.plist
echo "创建 Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>ByteFlow</string>
    <key>CFBundleIdentifier</key>
    <string>com.byteflow.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ByteFlow</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>2.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.14</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>ByteFlow 需要访问网络统计信息来监控应用流量。</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>ByteFlow 需要系统权限来运行 nettop 命令采集网络数据。</string>
</dict>
</plist>
PLIST_EOF

# 创建启动器（使用 bundled Python）
echo "创建启动器脚本..."
cat > "$APP_BUNDLE/Contents/MacOS/ByteFlow" <<'LAUNCHER_EOF'
#!/bin/bash
# ByteFlow Portable Launcher
# 使用内嵌的 Python 运行时，不依赖系统 Python

set -e

# 获取应用路径
APP_PATH="$(cd "$(dirname "$0")/../.." && pwd)"
CONTENTS_PATH="$APP_PATH/Contents"
RESOURCES_PATH="$CONTENTS_PATH/Resources"
FRAMEWORKS_PATH="$CONTENTS_PATH/Frameworks"

# 内嵌的 Python
BUNDLED_PYTHON="$FRAMEWORKS_PATH/Python.framework/bin/python3"

# 数据目录（可写）
DATA_DIR="$HOME/Library/Application Support/ByteFlow"
INSTALL_MARKER="$DATA_DIR/.installed"
CONFIG_DIR="$DATA_DIR"
LOGS_DIR="$DATA_DIR/logs"
PIDS_DIR="$DATA_DIR/.pids"

# 首次运行检测
FIRST_RUN=false
if [ ! -f "$INSTALL_MARKER" ]; then
    FIRST_RUN=true
fi

# 验证 bundled Python
if [ ! -f "$BUNDLED_PYTHON" ]; then
    osascript -e 'display alert "错误" message "ByteFlow 应用包损坏\n\n未找到内嵌的 Python 运行时。\n请重新下载 ByteFlow.dmg。" as critical'
    exit 1
fi

# 首次运行：显示欢迎对话框
if [ "$FIRST_RUN" = true ]; then
    osascript <<EOF
display dialog "欢迎使用 ByteFlow 网络流量监控！

这是一个便携式版本，内嵌 Python 运行时。
无需安装系统 Python 或其他依赖。

点击"继续"开始首次配置..." buttons {"退出", "继续"} default button "继续" with icon note with title "ByteFlow 安装"
EOF
    
    if [ $? -ne 0 ]; then
        exit 0
    fi
    
    osascript -e 'display notification "正在初始化 ByteFlow..." with title "ByteFlow"'
fi

# 创建数据目录
mkdir -p "$DATA_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOGS_DIR"
mkdir -p "$PIDS_DIR"

# 首次运行：复制默认配置
if [ "$FIRST_RUN" = true ]; then
    if [ -f "$RESOURCES_PATH/byteflow_config.json" ]; then
        cp "$RESOURCES_PATH/byteflow_config.json" "$CONFIG_DIR/" || true
    fi
    
    # 询问是否开机启动
    osascript <<EOF
set loginItemResponse to button returned of (display dialog "是否设置 ByteFlow 开机自动启动？

建议启用以便持续监控网络流量。" buttons {"否", "是"} default button "是" with title "ByteFlow 设置")

if loginItemResponse is "是" then
    return "yes"
else
    return "no"
end if
EOF
    
    LOGIN_ITEM_RESPONSE=$?
    
    if [ $LOGIN_ITEM_RESPONSE -eq 0 ]; then
        # 创建 LaunchAgent
        LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
        LAUNCH_AGENT_PLIST="$LAUNCH_AGENT_DIR/com.byteflow.app.plist"
        
        mkdir -p "$LAUNCH_AGENT_DIR"
        
        cat > "$LAUNCH_AGENT_PLIST" <<PLIST_EOF2
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.byteflow.app</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_PATH/Contents/MacOS/ByteFlow</string>
        <string>--background</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>$LOGS_DIR/launchd.log</string>
    <key>StandardErrorPath</key>
    <string>$LOGS_DIR/launchd.err</string>
</dict>
</plist>
PLIST_EOF2
        
        launchctl load "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
        osascript -e 'display notification "开机启动已设置" with title "ByteFlow"'
    fi
    
    # 标记为已安装
    touch "$INSTALL_MARKER"
    echo "Installation completed at $(date)" > "$INSTALL_MARKER"
    echo "Bundled Python: $BUNDLED_PYTHON" >> "$INSTALL_MARKER"
    "$BUNDLED_PYTHON" --version >> "$INSTALL_MARKER"
    
    osascript -e 'display notification "配置完成！正在启动..." with title "ByteFlow"'
fi

# 检查是否是后台启动
BACKGROUND_MODE=false
if [ "$1" = "--background" ]; then
    BACKGROUND_MODE=true
fi

# 设置环境变量
export PYTHONUNBUFFERED=1
export BYTEFLOW_DATA_DIR="$DATA_DIR"
export BYTEFLOW_CONFIG_DIR="$CONFIG_DIR"

# 检查是否已经在运行
if [ -f "$PIDS_DIR/collector.pid" ]; then
    COLLECTOR_PID=$(cat "$PIDS_DIR/collector.pid")
    if ps -p $COLLECTOR_PID > /dev/null 2>&1; then
        # 已在运行，只打开浏览器
        if [ "$BACKGROUND_MODE" = false ]; then
            sleep 1
            open "http://127.0.0.1:8787"
        fi
        exit 0
    fi
fi

# 切换到 Resources 目录（代码位置）
cd "$RESOURCES_PATH"

# 启动采集器
"$BUNDLED_PYTHON" collector.py > "$LOGS_DIR/collector.log" 2>&1 &
COLLECTOR_PID=$!
echo $COLLECTOR_PID > "$PIDS_DIR/collector.pid"

# 启动 API 服务器
sleep 1
"$BUNDLED_PYTHON" api.py > "$LOGS_DIR/api.log" 2>&1 &
API_PID=$!
echo $API_PID > "$PIDS_DIR/api.pid"

# 等待服务启动
sleep 2

# 非后台模式：启动桌面应用
if [ "$BACKGROUND_MODE" = false ]; then
    osascript -e 'display notification "正在启动 ByteFlow 桌面应用..." with title "ByteFlow"'
    
    # 检查 pywebview 是否可用
    "$BUNDLED_PYTHON" -c "import webview" 2>/dev/null
    if [ $? -eq 0 ]; then
        # 启动桌面窗口（前台）
        "$BUNDLED_PYTHON" desktop.py
    else
        # 降级：使用浏览器
        osascript -e 'display notification "pywebview 不可用，使用浏览器" with title "ByteFlow"'
        open "http://127.0.0.1:8787"
    fi
fi

exit 0
LAUNCHER_EOF

chmod +x "$APP_BUNDLE/Contents/MacOS/ByteFlow"

echo "✓ 启动器创建完成"
echo ""

# 创建 Applications 快捷方式
echo "创建 DMG 内容..."
ln -s /Applications "$BUILD_DIR/Applications"

# 创建中文说明
cat > "$BUILD_DIR/使用说明.txt" <<EOF
ByteFlow v2.0 便携版 - macOS 网络流量监控
架构: ${DMG_ARCH}

✨ 便携式版本特点:
• 内嵌 Python ${PYTHON_VERSION} 运行时
• 无需安装系统 Python 或 pip
• 无需联网安装依赖
• 开箱即用

安装方法:
方式1（推荐）: 将 ByteFlow.app 拖动到 Applications 文件夹
方式2: 双击 ByteFlow.app 直接运行

首次运行:
• 应用会自动配置数据目录
• 数据存储位置: ~/Library/Application Support/ByteFlow
• 可选择是否开机启动
• 浏览器自动打开 Web 界面

Gatekeeper 提示（未签名应用）:
右键点击 ByteFlow.app → 打开 → 确认打开
或：系统偏好设置 → 安全性与隐私 → 通用 → "仍要打开"

权限配置（必需）:
系统偏好设置 → 安全性与隐私 → 隐私 → 完全磁盘访问
添加: Terminal.app 或 ByteFlow.app

使用:
• 双击 ByteFlow.app 启动
• 浏览器访问 http://127.0.0.1:8787
• 支持菜单栏显示（可选）

卸载:
• 删除 /Applications/ByteFlow.app
• 删除 ~/Library/LaunchAgents/com.byteflow.app.plist (如设置了开机启动)
• 删除 ~/Library/Application Support/ByteFlow (数据和配置)

系统要求:
• macOS 10.14+
• 架构: ${DMG_ARCH}
• 磁盘空间: ~150MB

技术信息:
• 内嵌 Python: ${PYTHON_VERSION}
• 来源: python-build-standalone
• 依赖: FastAPI, Uvicorn, aiosqlite, rumps, pyobjc

更多信息: https://github.com/Freegxx/byteflow
EOF

# 计算构建目录大小
echo "计算 DMG 大小..."
BUILD_SIZE=$(du -sm "$BUILD_DIR" | cut -f1)
DMG_SIZE=$((BUILD_SIZE + 100))  # 添加 100MB 缓冲

echo "构建目录大小: ${BUILD_SIZE}MB"
echo "DMG 大小: ${DMG_SIZE}MB"
echo ""

# 创建临时 DMG
echo "创建临时 DMG..."
hdiutil create -size ${DMG_SIZE}m -fs HFS+ -volname "$VOLUME_NAME" -ov "$TEMP_DMG"

# 挂载临时 DMG
echo "挂载临时 DMG..."
MOUNT_POINT=$(hdiutil attach "$TEMP_DMG" | grep "/Volumes/" | sed 's/.*\(\/Volumes\/.*\)/\1/')

if [ -z "$MOUNT_POINT" ]; then
    echo "错误: 无法挂载 DMG"
    exit 1
fi

echo "挂载点: $MOUNT_POINT"

# 复制文件到 DMG
echo "复制文件到 DMG..."
cp -R "$BUILD_DIR/ByteFlow.app" "$MOUNT_POINT/"
cp -R "$BUILD_DIR/Applications" "$MOUNT_POINT/"
cp "$BUILD_DIR/使用说明.txt" "$MOUNT_POINT/"

# 设置 DMG 窗口外观
echo "设置 DMG 外观..."
echo '
   tell application "Finder"
     tell disk "'$VOLUME_NAME'"
           open
           set current view of container window to icon view
           set toolbar visible of container window to false
           set statusbar visible of container window to false
           set the bounds of container window to {100, 100, 600, 400}
           set viewOptions to the icon view options of container window
           set arrangement of viewOptions to not arranged
           set icon size of viewOptions to 128
           set position of item "ByteFlow.app" of container window to {120, 150}
           set position of item "Applications" of container window to {380, 150}
           set position of item "使用说明.txt" of container window to {250, 280}
           close
           open
           update without registering applications
           delay 2
     end tell
   end tell
' | osascript || echo "警告: 无法设置 DMG 外观"

# 卸载 DMG
echo "卸载 DMG..."
hdiutil detach "$MOUNT_POINT"

# 转换为压缩的只读 DMG
echo "转换为压缩只读 DMG..."
hdiutil convert "$TEMP_DMG" -format UDZO -o "$DMG_NAME"

# 清理
echo "清理临时文件..."
rm -f "$TEMP_DMG"

# 可选：保留 build_portable 目录以便调试
# rm -rf "$BUILD_DIR"

# 获取最终 DMG 大小
DMG_SIZE_FINAL=$(du -h "$DMG_NAME" | cut -f1)

echo ""
echo "======================================"
echo "✓ 便携式 DMG 创建成功!"
echo "======================================"
echo ""
echo "输出文件: $DMG_NAME"
echo "文件大小: $DMG_SIZE_FINAL"
echo "架构: $DMG_ARCH"
echo "内嵌 Python: $PYTHON_VERSION"
echo ""
echo "分发说明:"
echo "  ✓ 此 DMG 可在任何 ${DMG_ARCH} Mac 上离线安装"
echo "  ✓ 无需目标机器安装 Python 或 pip"
echo "  ✓ 无需联网安装依赖"
echo "  ✓ 开箱即用"
echo ""
echo "用户安装步骤:"
echo "  1. 双击打开 $DMG_NAME"
echo "  2. 将 ByteFlow.app 拖到 Applications"
echo "  3. 右键 > 打开（绕过 Gatekeeper）"
echo "  4. 浏览器自动打开 http://127.0.0.1:8787"
echo ""
echo "注意事项:"
echo "  • 首次运行需授予终端"完全磁盘访问"权限"
echo "  • 数据存储在 ~/Library/Application Support/ByteFlow"
echo "  • 此 DMG 仅适用于 ${DMG_ARCH} 架构"
echo ""
if [[ "$DMG_ARCH" == "arm64" ]]; then
    echo "提示: 要构建 x86_64 版本，请在 Intel Mac 上运行此脚本"
else
    echo "提示: 要构建 arm64 版本，请在 Apple Silicon Mac 上运行此脚本"
fi
echo ""
