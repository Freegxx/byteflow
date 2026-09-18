#!/bin/bash
# Build ByteFlow.dmg installer
# 构建 ByteFlow DMG 安装包
# 
# 注意：此脚本必须在 macOS 上运行

set -e

echo "======================================"
echo "ByteFlow DMG Builder"
echo "======================================"
echo ""

# 检查是否在 macOS 上
if [[ "$(uname)" != "Darwin" ]]; then
    echo "错误: 此脚本仅能在 macOS 上运行"
    echo "需要使用 hdiutil 工具来创建 DMG"
    exit 1
fi

# 配置
APP_NAME="ByteFlow"
DMG_NAME="ByteFlow-v2.0.dmg"
TEMP_DMG="temp.dmg"
SOURCE_DIR="$(pwd)"
BUILD_DIR="$SOURCE_DIR/build"
APP_BUNDLE="ByteFlow.app"
VOLUME_NAME="ByteFlow Installer"

echo "清理旧的构建文件..."
rm -rf "$BUILD_DIR"
rm -f "$DMG_NAME"
rm -f "$TEMP_DMG"

echo "创建构建目录..."
mkdir -p "$BUILD_DIR"

echo "复制应用到构建目录..."
# 复制 .app bundle
cp -R "$APP_BUNDLE" "$BUILD_DIR/"

# 复制应用代码到 Resources
echo "复制应用代码到 Resources..."
RESOURCES_DIR="$BUILD_DIR/$APP_BUNDLE/Contents/Resources"

# 复制 Python 代码和资源
cp *.py "$RESOURCES_DIR/" 2>/dev/null || true
cp *.txt "$RESOURCES_DIR/" 2>/dev/null || true
cp *.sh "$RESOURCES_DIR/" 2>/dev/null || true
cp *.md "$RESOURCES_DIR/" 2>/dev/null || true
cp *.json "$RESOURCES_DIR/" 2>/dev/null || true

# 复制 web 目录
if [ -d "web" ]; then
    cp -R web "$RESOURCES_DIR/"
fi

# 复制 Install.command 作为备选
cp Install.command "$RESOURCES_DIR/" 2>/dev/null || true

# 创建 Applications 快捷方式（拖拽式安装）
echo "创建 Applications 链接..."
ln -s /Applications "$BUILD_DIR/Applications"

# 创建 README
cat > "$BUILD_DIR/使用说明.txt" <<EOF
ByteFlow v2.0 - macOS 网络流量监控

安装方法:
方式1（推荐）: 将 ByteFlow.app 拖动到 Applications 文件夹
方式2: 双击 ByteFlow.app 直接运行

首次运行:
• 应用会自动安装依赖
• 需要授予终端权限（系统偏好设置 > 安全性与隐私 > 完全磁盘访问）
• 可选择是否开机启动

使用:
• 双击 ByteFlow.app 启动
• 浏览器自动打开 http://127.0.0.1:8787
• 支持菜单栏显示（可选）

卸载:
• 删除 /Applications/ByteFlow.app
• 删除 ~/Library/LaunchAgents/com.byteflow.app.plist (如设置了开机启动)
• 删除 ~/.byteflow (数据和配置)

更多信息: https://github.com/Freegxx/byteflow
EOF

echo "计算构建目录大小..."
BUILD_SIZE=$(du -sm "$BUILD_DIR" | cut -f1)
DMG_SIZE=$((BUILD_SIZE + 50))  # 添加 50MB 缓冲

echo "创建临时 DMG (${DMG_SIZE}MB)..."
hdiutil create -size ${DMG_SIZE}m -fs HFS+ -volname "$VOLUME_NAME" -ov "$TEMP_DMG"

echo "挂载临时 DMG..."
MOUNT_POINT=$(hdiutil attach "$TEMP_DMG" | grep "/Volumes/" | sed 's/.*\(\/Volumes\/.*\)/\1/')

if [ -z "$MOUNT_POINT" ]; then
    echo "错误: 无法挂载 DMG"
    exit 1
fi

echo "挂载点: $MOUNT_POINT"

echo "复制文件到 DMG..."
cp -R "$BUILD_DIR/"* "$MOUNT_POINT/"

# 设置 DMG 窗口外观（可选）
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
           set position of item "'$APP_NAME'.app" of container window to {120, 150}
           set position of item "Applications" of container window to {380, 150}
           set position of item "使用说明.txt" of container window to {250, 280}
           close
           open
           update without registering applications
           delay 2
     end tell
   end tell
' | osascript || echo "警告: 无法设置 DMG 外观"

echo "卸载 DMG..."
hdiutil detach "$MOUNT_POINT"

echo "转换为压缩的只读 DMG..."
hdiutil convert "$TEMP_DMG" -format UDZO -o "$DMG_NAME"

echo "清理临时文件..."
rm -f "$TEMP_DMG"
rm -rf "$BUILD_DIR"

echo ""
echo "======================================"
echo "✓ DMG 创建成功!"
echo "======================================"
echo ""
echo "输出文件: $DMG_NAME"
echo "文件大小: $(du -h "$DMG_NAME" | cut -f1)"
echo ""
echo "分发说明:"
echo "  1. 双击打开 $DMG_NAME"
echo "  2. 将 ByteFlow.app 拖到 Applications"
echo "  3. 或直接双击 ByteFlow.app 运行"
echo ""
echo "首次运行提示用户:"
echo "  • 右键 > 打开（绕过 Gatekeeper）"
echo "  • 授予终端"完全磁盘访问"权限"
echo ""
