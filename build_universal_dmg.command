#!/bin/bash
# Build Universal ByteFlow DMG (arm64 + x86_64)
# 构建通用 ByteFlow DMG（支持 Apple Silicon 和 Intel Mac）
#
# 必须在 macOS 上运行
# 生成单个 DMG，内含两套 Python 运行时，启动器自动检测架构

set -e

echo "======================================"
echo "ByteFlow Universal DMG Builder"
echo "通用 DMG 构建器（arm64 + x86_64）"
echo "======================================"
echo ""

# 检查是否在 macOS 上
if [[ "$(uname)" != "Darwin" ]]; then
    echo "错误: 此脚本仅能在 macOS 上运行"
    exit 1
fi

echo "当前构建机架构: $(uname -m)"
echo "将构建包含 arm64 + x86_64 双架构的通用 DMG"
echo ""

# 配置
APP_NAME="ByteFlow"
VERSION="2.0"
DMG_NAME="ByteFlow-universal.dmg"
TEMP_DMG="temp.dmg"
SOURCE_DIR="$(pwd)"
BUILD_DIR="$SOURCE_DIR/build_universal"
APP_BUNDLE="$BUILD_DIR/ByteFlow.app"
VOLUME_NAME="ByteFlow Installer"

# Python 配置 - Python 3.11.9
PYTHON_VERSION="3.11.9"
PYTHON_BUILD_STANDALONE_VERSION="20240713"

# Python URLs for both architectures
PYTHON_ARM64_URL="https://github.com/indygreg/python-build-standalone/releases/download/${PYTHON_BUILD_STANDALONE_VERSION}/cpython-${PYTHON_VERSION}+${PYTHON_BUILD_STANDALONE_VERSION}-aarch64-apple-darwin-install_only.tar.gz"
PYTHON_X86_64_URL="https://github.com/indygreg/python-build-standalone/releases/download/${PYTHON_BUILD_STANDALONE_VERSION}/cpython-${PYTHON_VERSION}+${PYTHON_BUILD_STANDALONE_VERSION}-x86_64-apple-darwin-install_only.tar.gz"

PYTHON_ARM64_TARBALL="python-${PYTHON_VERSION}-arm64.tar.gz"
PYTHON_X86_64_TARBALL="python-${PYTHON_VERSION}-x86_64.tar.gz"

echo "Python 配置:"
echo "  版本: ${PYTHON_VERSION}"
echo "  架构: arm64 + x86_64 (双架构)"
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

# ==========================================
# 下载 Python - arm64
# ==========================================
if [ ! -f "$PYTHON_ARM64_TARBALL" ]; then
    echo "下载 Python ${PYTHON_VERSION} for arm64..."
    curl -L -o "$PYTHON_ARM64_TARBALL" "$PYTHON_ARM64_URL"
    
    if [ $? -ne 0 ]; then
        echo "错误: Python arm64 下载失败"
        rm -f "$PYTHON_ARM64_TARBALL"
        exit 1
    fi
    echo "✓ Python arm64 下载完成"
else
    echo "使用已缓存的 Python arm64: $PYTHON_ARM64_TARBALL"
fi

# ==========================================
# 下载 Python - x86_64
# ==========================================
if [ ! -f "$PYTHON_X86_64_TARBALL" ]; then
    echo "下载 Python ${PYTHON_VERSION} for x86_64..."
    curl -L -o "$PYTHON_X86_64_TARBALL" "$PYTHON_X86_64_URL"
    
    if [ $? -ne 0 ]; then
        echo "错误: Python x86_64 下载失败"
        rm -f "$PYTHON_X86_64_TARBALL"
        exit 1
    fi
    echo "✓ Python x86_64 下载完成"
else
    echo "使用已缓存的 Python x86_64: $PYTHON_X86_64_TARBALL"
fi

echo ""

# ==========================================
# 解压 Python - arm64
# ==========================================
echo "解压 Python arm64 到应用包..."
PYTHON_ARM64_DIR="$APP_BUNDLE/Contents/Frameworks/Python-arm64.framework"
mkdir -p "$PYTHON_ARM64_DIR"

tar -xzf "$PYTHON_ARM64_TARBALL" -C "$PYTHON_ARM64_DIR" --strip-components=1

if [ $? -ne 0 ]; then
    echo "错误: Python arm64 解压失败"
    exit 1
fi

BUNDLED_PYTHON_ARM64="$PYTHON_ARM64_DIR/bin/python3"
if [ ! -f "$BUNDLED_PYTHON_ARM64" ]; then
    echo "错误: 未找到 Python arm64 可执行文件"
    exit 1
fi

echo "✓ Python arm64 解压完成"

# ==========================================
# 解压 Python - x86_64
# ==========================================
echo "解压 Python x86_64 到应用包..."
PYTHON_X86_64_DIR="$APP_BUNDLE/Contents/Frameworks/Python-x86_64.framework"
mkdir -p "$PYTHON_X86_64_DIR"

tar -xzf "$PYTHON_X86_64_TARBALL" -C "$PYTHON_X86_64_DIR" --strip-components=1

if [ $? -ne 0 ]; then
    echo "错误: Python x86_64 解压失败"
    exit 1
fi

BUNDLED_PYTHON_X86_64="$PYTHON_X86_64_DIR/bin/python3"
if [ ! -f "$BUNDLED_PYTHON_X86_64" ]; then
    echo "错误: 未找到 Python x86_64 可执行文件"
    exit 1
fi

echo "✓ Python x86_64 解压完成"
echo ""

# ==========================================
# 安装依赖 - arm64
# ==========================================
echo "安装依赖到 Python arm64..."
echo "  - 核心依赖 (requirements_bundle.txt)"

cat > "$BUILD_DIR/requirements_bundle.txt" <<EOF
fastapi==0.115.0
uvicorn==0.30.6
python-multipart==0.0.12
aiosqlite==0.20.0
pywebview==5.3
requests==2.32.3
EOF

"$BUNDLED_PYTHON_ARM64" -m pip install --upgrade pip -q
"$BUNDLED_PYTHON_ARM64" -m pip install -r "$BUILD_DIR/requirements_bundle.txt" -q

echo "  - 菜单栏依赖 (requirements_menubar_bundle.txt)"

cat > "$BUILD_DIR/requirements_menubar_bundle.txt" <<EOF
pyobjc-core==10.3.1
pyobjc-framework-Cocoa==10.3.1
rumps==0.4.0
EOF

"$BUNDLED_PYTHON_ARM64" -m pip install -r "$BUILD_DIR/requirements_menubar_bundle.txt" -q || {
    echo "警告: 菜单栏依赖 (arm64) 安装失败（可选功能）"
}

echo "✓ Python arm64 依赖安装完成"

# ==========================================
# 安装依赖 - x86_64
# ==========================================
echo "安装依赖到 Python x86_64..."
echo "  - 核心依赖 (requirements_bundle.txt)"

"$BUNDLED_PYTHON_X86_64" -m pip install --upgrade pip -q
"$BUNDLED_PYTHON_X86_64" -m pip install -r "$BUILD_DIR/requirements_bundle.txt" -q

echo "  - 菜单栏依赖 (requirements_menubar_bundle.txt)"

"$BUNDLED_PYTHON_X86_64" -m pip install -r "$BUILD_DIR/requirements_menubar_bundle.txt" -q || {
    echo "警告: 菜单栏依赖 (x86_64) 安装失败（可选功能）"
}

echo "✓ Python x86_64 依赖安装完成"
echo ""

# ==========================================
# 复制应用代码到 Resources
# ==========================================
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

# ==========================================
# 创建 Info.plist
# ==========================================
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

# ==========================================
# 创建通用启动器（架构检测）
# ==========================================
echo "创建通用启动器脚本..."
cat > "$APP_BUNDLE/Contents/MacOS/ByteFlow" <<'LAUNCHER_EOF'
#!/bin/bash
# ByteFlow Universal Launcher
# 通用启动器 - 自动检测架构并使用对应的 Python

set -e

# 获取应用路径
APP_PATH="$(cd "$(dirname "$0")/../.." && pwd)"
CONTENTS_PATH="$APP_PATH/Contents"
RESOURCES_PATH="$CONTENTS_PATH/Resources"
FRAMEWORKS_PATH="$CONTENTS_PATH/Frameworks"

# 检测当前架构
CURRENT_ARCH=$(uname -m)

# 根据架构选择对应的 Python
if [[ "$CURRENT_ARCH" == "arm64" ]]; then
    PYTHON_DIR="$FRAMEWORKS_PATH/Python-arm64.framework"
    ARCH_NAME="arm64 (Apple Silicon)"
elif [[ "$CURRENT_ARCH" == "x86_64" ]]; then
    PYTHON_DIR="$FRAMEWORKS_PATH/Python-x86_64.framework"
    ARCH_NAME="x86_64 (Intel)"
else
    osascript -e "display alert \"不支持的架构\" message \"当前架构: $CURRENT_ARCH\n\nByteFlow 仅支持 arm64 和 x86_64。\" as critical"
    exit 1
fi

BUNDLED_PYTHON="$PYTHON_DIR/bin/python3"

# 验证 bundled Python
if [ ! -f "$BUNDLED_PYTHON" ]; then
    osascript -e "display alert \"错误\" message \"ByteFlow 应用包损坏\n\n未找到 $ARCH_NAME Python 运行时。\n请重新下载 ByteFlow.dmg。\" as critical"
    exit 1
fi

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

# 首次运行：显示欢迎对话框
if [ "$FIRST_RUN" = true ]; then
    osascript <<EOF
display dialog "欢迎使用 ByteFlow 网络流量监控！

这是通用版本，支持 Apple Silicon 和 Intel Mac。

检测到架构: $ARCH_NAME

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
    echo "Architecture: $CURRENT_ARCH" >> "$INSTALL_MARKER"
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

# 非后台模式：启动桌面应用（前台）
if [ "$BACKGROUND_MODE" = false ]; then
    osascript -e 'display notification "正在启动 ByteFlow 桌面应用..." with title "ByteFlow"'
    
    # 检查 pywebview 是否可用
    "$BUNDLED_PYTHON" -c "import webview" 2>/dev/null
    if [ $? -eq 0 ]; then
        # 使用桌面窗口（desktop.py 会自动启动和管理服务）
        cd "$RESOURCES_PATH"
        exec "$BUNDLED_PYTHON" desktop.py
    else
        # 降级：pywebview 不可用
        osascript -e 'display notification "pywebview 不可用，使用浏览器模式" with title "ByteFlow"'
    fi
fi

# 后台模式或降级模式：手动启动服务
# 检查是否已经在运行
if [ -f "$PIDS_DIR/collector.pid" ]; then
    COLLECTOR_PID=$(cat "$PIDS_DIR/collector.pid")
    if ps -p $COLLECTOR_PID > /dev/null 2>&1; then
        # 已在运行，只打开浏览器（降级模式）
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

# 降级模式：打开浏览器
if [ "$BACKGROUND_MODE" = false ]; then
    osascript -e 'display notification "ByteFlow 已启动\n访问地址: http://127.0.0.1:8787" with title "ByteFlow"'
    open "http://127.0.0.1:8787"
fi

exit 0
LAUNCHER_EOF

chmod +x "$APP_BUNDLE/Contents/MacOS/ByteFlow"

echo "✓ 启动器创建完成"
echo ""

# ==========================================
# 创建 DMG 内容
# ==========================================
echo "创建 DMG 内容..."
ln -s /Applications "$BUILD_DIR/Applications"

# 创建中文说明
cat > "$BUILD_DIR/使用说明.txt" <<EOF
ByteFlow v2.0 通用版 - macOS 网络流量监控
支持架构: Apple Silicon (arm64) + Intel (x86_64)

✨ 通用版本特点:
• 单个 DMG 支持所有 Mac
• 内嵌 Python ${PYTHON_VERSION} 双架构运行时
• 启动器自动检测并使用匹配的架构
• 无需安装系统 Python 或 pip
• 无需联网安装依赖
• 原生桌面窗口（不打开浏览器）
• 开箱即用

安装方法:
方式1（推荐）: 将 ByteFlow.app 拖动到 Applications 文件夹
方式2: 双击 ByteFlow.app 直接运行

首次运行:
• 应用会自动检测您的 Mac 架构
• 自动配置数据目录
• 数据存储位置: ~/Library/Application Support/ByteFlow
• 可选择是否开机启动
• 原生桌面窗口自动打开

Gatekeeper 提示（未签名应用）:
右键点击 ByteFlow.app → 打开 → 确认打开
或：系统偏好设置 → 安全性与隐私 → 通用 → "仍要打开"

权限配置（必需）:
系统偏好设置 → 安全性与隐私 → 隐私 → 完全磁盘访问
添加: Terminal.app 或 ByteFlow.app

使用:
• 双击 ByteFlow.app 启动
• 原生桌面窗口显示流量监控
• 支持菜单栏显示（可选）

卸载:
• 删除 /Applications/ByteFlow.app
• 删除 ~/Library/LaunchAgents/com.byteflow.app.plist (如设置了开机启动)
• 删除 ~/Library/Application Support/ByteFlow (数据和配置)

系统要求:
• macOS 10.14+
• Apple Silicon (M1/M2/M3) 或 Intel Mac
• 磁盘空间: ~300MB

技术信息:
• 内嵌 Python: ${PYTHON_VERSION} (arm64 + x86_64)
• 来源: python-build-standalone
• 依赖: FastAPI, Uvicorn, aiosqlite, pywebview, rumps, pyobjc

更多信息: https://github.com/Freegxx/byteflow
EOF

# ==========================================
# 创建 DMG
# ==========================================
# 计算构建目录大小
echo "计算 DMG 大小..."
BUILD_SIZE=$(du -sm "$BUILD_DIR" | cut -f1)
DMG_SIZE=$((BUILD_SIZE + 150))  # 添加 150MB 缓冲

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

# 可选：保留 build_universal 目录以便调试
# rm -rf "$BUILD_DIR"

# 获取最终 DMG 大小
DMG_SIZE_FINAL=$(du -h "$DMG_NAME" | cut -f1)

echo ""
echo "======================================"
echo "✓ 通用 DMG 创建成功!"
echo "======================================"
echo ""
echo "输出文件: $DMG_NAME"
echo "文件大小: $DMG_SIZE_FINAL"
echo "支持架构: Apple Silicon (arm64) + Intel (x86_64)"
echo "内嵌 Python: $PYTHON_VERSION (双架构)"
echo ""
echo "分发说明:"
echo "  ✓ 单个 DMG 支持所有 Mac"
echo "  ✓ 启动器自动检测架构"
echo "  ✓ 无需用户关心架构选择"
echo "  ✓ 完全离线安装"
echo ""
echo "用户安装步骤:"
echo "  1. 双击打开 $DMG_NAME"
echo "  2. 将 ByteFlow.app 拖到 Applications"
echo "  3. 右键 > 打开（绕过 Gatekeeper）"
echo "  4. 原生桌面窗口自动打开"
echo ""
echo "注意事项:"
echo "  • 首次运行需授予终端"完全磁盘访问"权限"
echo "  • 数据存储在 ~/Library/Application Support/ByteFlow"
echo "  • 启动器会根据当前 Mac 架构自动选择对应的 Python"
echo ""
echo "复制到用户 Mac（如需要）:"
echo "  cp $DMG_NAME /Users/guxx/Developer/Personal/byteflow/"
echo ""
