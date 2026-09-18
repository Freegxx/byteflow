# ByteFlow DMG 构建指南

本文档说明如何构建 ByteFlow.dmg 安装包。

## 概述

ByteFlow 提供两种安装方式：
1. **ByteFlow.dmg** - 双击安装的磁盘映像（推荐）
2. **Install.command** - 命令行安装脚本（备选）

## 前置要求

**必须在 macOS 上构建**：
- macOS 10.14 或更高版本
- Xcode Command Line Tools
- hdiutil（macOS 自带）

安装 Command Line Tools：
```bash
xcode-select --install
```

## 快速构建

```bash
# 克隆或进入项目目录
cd byteflow

# 运行构建脚本
./build_dmg.sh

# 输出: ByteFlow-v2.0.dmg
```

## 构建产物

### ByteFlow.dmg 内容

```
ByteFlow Installer/
├── ByteFlow.app/           # 可拖拽到 Applications 或双击运行
│   └── Contents/
│       ├── MacOS/
│       │   └── ByteFlow    # 启动脚本
│       ├── Resources/      # 应用代码和资源
│       │   ├── *.py        # Python 源码
│       │   ├── web/        # Web UI
│       │   ├── requirements.txt
│       │   └── ...
│       └── Info.plist      # 应用信息
├── Applications → /Applications  # 拖拽快捷方式
└── 使用说明.txt           # 安装说明
```

### ByteFlow.app 行为

**首次运行**（双击 .app）:
1. 显示欢迎对话框
2. 创建 Python venv 在 `Contents/Resources/venv`
3. 安装核心依赖（requirements.txt）
4. 安装菜单栏依赖（可选，Python 3.9 自动 pin pyobjc 10.3.1）
5. 询问是否开机启动
6. 启动服务并打开浏览器

**后续运行**:
1. 检查服务是否已运行
2. 如未运行则启动服务
3. 打开浏览器到 http://127.0.0.1:8787

**开机启动**:
- 创建 `~/Library/LaunchAgents/com.byteflow.app.plist`
- 使用 `--background` 参数启动（不打开浏览器）

## 手动构建步骤

### 1. 准备 .app Bundle

```bash
# 创建目录结构
mkdir -p ByteFlow.app/Contents/{MacOS,Resources}

# 复制应用代码到 Resources
cp *.py ByteFlow.app/Contents/Resources/
cp -R web ByteFlow.app/Contents/Resources/
cp requirements*.txt ByteFlow.app/Contents/Resources/

# 设置启动脚本
chmod +x ByteFlow.app/Contents/MacOS/ByteFlow
```

### 2. 创建 DMG

```bash
# 方式1: 使用构建脚本（推荐）
./build_dmg.sh

# 方式2: 手动使用 hdiutil
hdiutil create -volname "ByteFlow Installer" \
  -srcfolder ByteFlow.app \
  -ov -format UDZO \
  ByteFlow.dmg
```

## 分发

### 给用户的安装说明

**安装步骤**:
1. 双击 `ByteFlow-v2.0.dmg` 打开磁盘映像
2. 两种安装方式任选其一：
   - **方式A（推荐）**: 将 ByteFlow.app 拖到 Applications 文件夹
   - **方式B**: 直接双击 ByteFlow.app 运行

**首次运行 Gatekeeper 提示**:
```
"ByteFlow.app" cannot be opened because it is from an unidentified developer
```

解决方法：
- **方法1**: 右键点击 ByteFlow.app → 打开 → 确认打开
- **方法2**: 系统偏好设置 → 安全性与隐私 → 通用 → "仍要打开"
- **方法3**（开发者）: 
  ```bash
  xattr -cr /Applications/ByteFlow.app
  ```

**授予权限**（必需）:
```
系统偏好设置 → 安全性与隐私 → 隐私 → 完全磁盘访问
添加: Terminal.app 或 ByteFlow.app
```

## .app 启动脚本详解

`ByteFlow.app/Contents/MacOS/ByteFlow` 做了什么：

### 1. 首次运行检测
```bash
if [ ! -f "$INSTALL_MARKER" ]; then
    FIRST_RUN=true
fi
```

### 2. 显示安装对话框
使用 `osascript` 显示 macOS 原生对话框：
```bash
osascript -e 'display dialog "欢迎使用 ByteFlow..." ...'
```

### 3. 创建虚拟环境
```bash
python3 -m venv "$RESOURCES_PATH/venv"
source "$RESOURCES_PATH/venv/bin/activate"
```

### 4. 安装依赖（带 pyobjc 版本处理）
```bash
pip install -r requirements.txt

# Python 3.9 特殊处理
if [ "$PYTHON_MINOR" = "9" ]; then
    pip install pyobjc-core==10.3.1 pyobjc-framework-Cocoa==10.3.1
fi

pip install -r requirements-menubar.txt || true  # 可选
```

### 5. 开机启动配置（可选）
用户选择"是"时创建 LaunchAgent：
```bash
cat > ~/Library/LaunchAgents/com.byteflow.app.plist <<EOF
...
<string>$APP_PATH/Contents/MacOS/ByteFlow</string>
<string>--background</string>
...
EOF
```

### 6. 启动服务
```bash
python3 collector.py &
python3 api.py &
open "http://127.0.0.1:8787"
```

### 7. 菜单栏应用（可选）
如果安装成功，询问是否启动：
```bash
python3 menubar.py &
```

## 故障排除

### 构建失败

**错误: hdiutil: command not found**
```bash
# 检查 Command Line Tools
xcode-select -p

# 安装
xcode-select --install
```

**错误: hdiutil: create failed - Resource busy**
```bash
# 卸载所有挂载的卷
hdiutil detach "/Volumes/ByteFlow Installer" -force

# 清理
rm -f temp.dmg
```

### 运行失败

**应用不启动**:
```bash
# 查看控制台日志
log show --predicate 'process == "ByteFlow"' --last 5m

# 手动测试启动脚本
./ByteFlow.app/Contents/MacOS/ByteFlow

# 查看安装日志
cat /tmp/byteflow_install.log
```

**依赖安装失败**:
```bash
# 进入 Resources 手动安装
cd ByteFlow.app/Contents/Resources
source venv/bin/activate
pip install -r requirements.txt -v
```

**pyobjc 版本问题（Python 3.9）**:
```bash
# 启动脚本会自动处理，或手动 pin 版本
pip install pyobjc-core==10.3.1 pyobjc-framework-Cocoa==10.3.1
pip install rumps==0.4.0
```

## 代码签名（可选）

为了通过 Gatekeeper 验证，可以对 .app 进行代码签名：

```bash
# 需要 Apple Developer 账号和证书

# 签名
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name" \
  ByteFlow.app

# 验证
codesign --verify --deep --verbose=2 ByteFlow.app

# 公证（notarization）
xcrun notarytool submit ByteFlow-v2.0.dmg \
  --apple-id your@email.com \
  --team-id TEAMID \
  --wait

# 装订公证票据
xcrun stapler staple ByteFlow.app
```

**注意**: 未签名的应用仍可使用，只需用户"右键 > 打开"绕过 Gatekeeper。

## 最佳实践

### 1. 版本号管理
更新 `Info.plist` 中的版本号：
```xml
<key>CFBundleShortVersionString</key>
<string>2.0.0</string>
```

### 2. 测试清单

构建后测试：
- [ ] DMG 可以双击打开
- [ ] .app 可以拖到 Applications
- [ ] 双击 .app 显示欢迎对话框
- [ ] 依赖安装成功
- [ ] 服务启动成功
- [ ] 浏览器打开 Web UI
- [ ] 开机启动选项工作
- [ ] 菜单栏应用可用（如安装）
- [ ] 卸载干净

### 3. 清理测试环境

```bash
# 完全卸载（测试用）
rm -rf /Applications/ByteFlow.app
rm ~/Library/LaunchAgents/com.byteflow.app.plist
launchctl unload ~/Library/LaunchAgents/com.byteflow.app.plist
rm -rf ~/.byteflow
```

## 与 Install.command 的区别

| 特性 | ByteFlow.app | Install.command |
|------|--------------|-----------------|
| 双击安装 | ✅ 是 | ✅ 是 |
| 图形界面 | ✅ macOS 对话框 | ❌ 终端界面 |
| 拖拽安装 | ✅ 是 | ❌ 否 |
| 启动方式 | 双击 .app | 运行脚本 |
| venv 位置 | .app 内部 | ~/Applications/ByteFlow |
| 适合用户 | 普通用户 | 技术用户 |
| Gatekeeper | 需要右键打开 | 需要右键打开 |

**推荐**: 普通用户使用 .dmg + .app，开发者使用 Install.command。

## 文件清单

新增文件：
- `ByteFlow.app/Contents/Info.plist` - 应用信息
- `ByteFlow.app/Contents/MacOS/ByteFlow` - 启动脚本
- `build_dmg.sh` - DMG 构建脚本
- `DMG_BUILD_GUIDE.md` - 本文档

保留文件：
- `Install.command` - 备选安装方式
- `requirements.txt` - 核心依赖
- `requirements-menubar.txt` - 菜单栏依赖

---

**构建环境**: macOS 10.14+  
**目标系统**: macOS 10.14+ (Intel & Apple Silicon)  
**输出**: ByteFlow-v2.0.dmg (~20-30MB)
