# ByteFlow 便携式 DMG 构建指南

## 概述

本指南说明如何构建**完全自包含**的 ByteFlow.dmg，内嵌 Python 运行时和所有依赖，可在任何 Mac 上离线安装运行，无需系统 Python 或 pip。

## 🎯 便携式 vs 标准版本

| 特性 | 便携式 DMG | 标准 DMG |
|------|-----------|---------|
| Python 来源 | 内嵌在 .app 中 | 系统 `/usr/bin/python3` |
| 依赖安装 | 预装在 .app 中 | 首次运行 pip install |
| 目标机器要求 | 仅 macOS | macOS + Python 3.8+ |
| 离线安装 | ✅ 完全离线 | ❌ 需联网装依赖 |
| DMG 大小 | ~150-200MB | ~2-5MB |
| 构建机要求 | macOS + 联网 | macOS |
| 适用场景 | 生产分发 | 开发测试 |

## 🔧 前置要求

### 构建机（Builder Mac）
- macOS 10.14+
- Xcode Command Line Tools
- 联网（一次性下载 Python + wheels）
- 磁盘空间 ~500MB

安装 Command Line Tools:
```bash
xcode-select --install
```

### 目标机（Target Mac）
- macOS 10.14+
- 相同架构（arm64 或 x86_64）
- 无需 Python
- 无需 pip
- 无需联网

## 🚀 快速构建

### 在 Apple Silicon Mac 上（构建 arm64 版本）

```bash
cd byteflow
./build_portable_dmg.sh

# 输出: ByteFlow-v2.0-arm64.dmg
```

### 在 Intel Mac 上（构建 x86_64 版本）

```bash
cd byteflow
./build_portable_dmg.sh

# 输出: ByteFlow-v2.0-x86_64.dmg
```

### 构建时间
- 首次构建：~5-10 分钟（下载 Python + 安装依赖）
- 后续构建：~2-3 分钟（使用缓存的 Python tarball）

## 📦 构建产物

### DMG 内容

```
ByteFlow Installer/
├── ByteFlow.app/                    # 便携式应用包
│   └── Contents/
│       ├── MacOS/
│       │   └── ByteFlow             # 启动器（使用 bundled Python）
│       ├── Frameworks/
│       │   └── Python.framework/    # 内嵌的 Python 3.11.9
│       │       ├── bin/
│       │       │   └── python3      # Python 可执行文件
│       │       ├── lib/
│       │       │   └── python3.11/  # 标准库 + site-packages
│       │       │       └── site-packages/
│       │       │           ├── fastapi/
│       │       │           ├── uvicorn/
│       │       │           ├── aiosqlite/
│       │       │           ├── rumps/
│       │       │           └── ...
│       │       └── ...
│       ├── Resources/
│       │   ├── *.py                 # 应用代码
│       │   ├── web/                 # Web UI
│       │   └── byteflow_config.json
│       └── Info.plist
├── Applications → /Applications      # 拖拽快捷方式
└── 使用说明.txt                     # 中文说明
```

### 文件大小

| 组件 | 大小 |
|------|------|
| Python 3.11 runtime | ~50MB |
| Python 标准库 | ~30MB |
| 依赖 (fastapi, uvicorn, etc.) | ~20MB |
| 应用代码 | ~1MB |
| **DMG 总大小** | **~150-200MB** |

## 🛠️ 技术实现

### 1. Python 来源

使用 [python-build-standalone](https://github.com/indygreg/python-build-standalone) 项目的预编译 Python：
- 官方 CPython 3.11.9
- 完全独立，无系统依赖
- 支持 macOS arm64 和 x86_64
- 包含 pip, setuptools, wheel

**下载 URL**:
- arm64: `cpython-3.11.9+20240713-aarch64-apple-darwin-install_only.tar.gz`
- x86_64: `cpython-3.11.9+20240713-x86_64-apple-darwin-install_only.tar.gz`

### 2. Python 安装位置

```
ByteFlow.app/Contents/Frameworks/Python.framework/
```

**为什么不用 venv**:
- venv 需要系统 Python
- 直接安装到 Python.framework 更简洁
- pip install 直接写入 site-packages

### 3. 依赖安装

构建时执行：
```bash
$BUNDLED_PYTHON -m pip install -r requirements.txt
```

依赖安装到：
```
Python.framework/lib/python3.11/site-packages/
```

**固定版本**（提高可靠性）:
```
fastapi==0.115.0
uvicorn==0.30.6
python-multipart==0.0.12
aiosqlite==0.20.0
pyobjc-core==10.3.1
pyobjc-framework-Cocoa==10.3.1
rumps==0.4.0
```

### 4. 启动器逻辑

`ByteFlow.app/Contents/MacOS/ByteFlow`:

```bash
# 定位 bundled Python
BUNDLED_PYTHON="$APP_PATH/Contents/Frameworks/Python.framework/bin/python3"

# 验证存在
if [ ! -f "$BUNDLED_PYTHON" ]; then
    osascript -e 'display alert "应用包损坏" ...'
    exit 1
fi

# 数据目录（可写）
DATA_DIR="$HOME/Library/Application Support/ByteFlow"

# 首次运行配置
if [ "$FIRST_RUN" = true ]; then
    # 欢迎对话框
    # 创建数据目录
    # 询问开机启动
    # ...
fi

# 启动服务（使用 bundled Python）
"$BUNDLED_PYTHON" collector.py &
"$BUNDLED_PYTHON" api.py &
```

**关键点**:
- ✅ **仅使用** `$BUNDLED_PYTHON`，从不调用 `/usr/bin/python3`
- ✅ 数据目录在 `~/Library/Application Support/ByteFlow`（.app 内只读）
- ✅ 日志、PID、数据库都在数据目录
- ✅ 首次运行复制默认配置到数据目录

### 5. 数据目录结构

```
~/Library/Application Support/ByteFlow/
├── .installed                      # 首次运行标记
├── byteflow_config.json            # 配置（从 Resources 复制）
├── byteflow.db                     # SQLite 数据库
├── logs/
│   ├── collector.log
│   ├── api.log
│   ├── menubar.log
│   └── launchd.log
└── .pids/
    ├── collector.pid
    ├── api.pid
    └── menubar.pid
```

## 📋 构建流程详解

### 第1步：架构检测
```bash
ARCH=$(uname -m)  # arm64 或 x86_64
```

### 第2步：下载 Python
```bash
curl -L -o python-3.11.9-$ARCH.tar.gz $PYTHON_URL
```

**缓存机制**:
- tarball 保存在当前目录
- 后续构建复用缓存（节省时间）

### 第3步：解压到 Frameworks
```bash
tar -xzf python-3.11.9-$ARCH.tar.gz \
  -C ByteFlow.app/Contents/Frameworks/Python.framework \
  --strip-components=1
```

### 第4步：安装依赖
```bash
$BUNDLED_PYTHON -m pip install --upgrade pip
$BUNDLED_PYTHON -m pip install -r requirements_bundle.txt
$BUNDLED_PYTHON -m pip install -r requirements_menubar_bundle.txt
```

### 第5步：复制应用代码
```bash
cp *.py Resources/
cp -R web Resources/
cp *.json Resources/
```

### 第6步：创建 Info.plist 和启动器
- Info.plist: 应用元数据
- 启动器: 使用 bundled Python 的 bash 脚本

### 第7步：创建 DMG
```bash
hdiutil create -size ${DMG_SIZE}m ...
hdiutil attach temp.dmg
cp -R ByteFlow.app /Volumes/...
hdiutil detach /Volumes/...
hdiutil convert temp.dmg -format UDZO -o ByteFlow-v2.0-$ARCH.dmg
```

## 🧪 测试

### 构建机测试

```bash
# 构建
./build_portable_dmg.sh

# 验证输出
ls -lh ByteFlow-v2.0-*.dmg

# 验证 Python bundled
ls -la build_portable/ByteFlow.app/Contents/Frameworks/Python.framework/bin/

# 验证依赖
build_portable/ByteFlow.app/Contents/Frameworks/Python.framework/bin/python3 -c "import fastapi; print(fastapi.__version__)"
```

### 目标机测试（干净环境）

**准备**:
```bash
# 移除系统 Python（测试用，慎重！）
# 或在没有 Python 的干净 Mac 上测试
which python3  # 应该找不到或版本不兼容
```

**安装测试**:
1. 双击 `ByteFlow-v2.0-arm64.dmg`
2. 拖拽 ByteFlow.app 到 Applications
3. 右键 > 打开（Gatekeeper）
4. 欢迎对话框 → 继续
5. 开机启动 → 是/否
6. 浏览器自动打开 `http://127.0.0.1:8787`

**功能测试**:
- [ ] Web UI 正常显示
- [ ] 应用列表加载
- [ ] 搜索/过滤工作
- [ ] 点击应用打开模态
- [ ] 图表渲染正常
- [ ] IP 列表显示
- [ ] 菜单栏应用（可选）

**验证无系统依赖**:
```bash
# 查看运行的 Python 进程
ps aux | grep python

# 应该显示:
# .../ByteFlow.app/Contents/Frameworks/Python.framework/bin/python3 collector.py
# .../ByteFlow.app/Contents/Frameworks/Python.framework/bin/python3 api.py

# 不应该是:
# /usr/bin/python3 ...
```

### 卸载测试
```bash
rm -rf /Applications/ByteFlow.app
rm ~/Library/LaunchAgents/com.byteflow.app.plist
launchctl unload ~/Library/LaunchAgents/com.byteflow.app.plist
rm -rf ~/Library/Application\ Support/ByteFlow
```

## 🌍 架构支持

### arm64 (Apple Silicon)
- M1, M2, M3, M4 Mac
- DMG: `ByteFlow-v2.0-arm64.dmg`
- 构建机: Apple Silicon Mac

### x86_64 (Intel)
- Intel Mac
- DMG: `ByteFlow-v2.0-x86_64.dmg`
- 构建机: Intel Mac

### Universal2（暂不支持）

构建 Universal2 需要:
1. 同时包含 arm64 和 x86_64 Python
2. Fat binary 或运行时选择架构
3. 复杂度高，DMG 大小翻倍

**推荐方案**: 分发两个架构特定的 DMG。

**用户选择**:
- M1/M2/M3 Mac → 下载 `ByteFlow-v2.0-arm64.dmg`
- Intel Mac → 下载 `ByteFlow-v2.0-x86_64.dmg`

## 🐛 故障排除

### 构建失败

**问题 1: Python 下载失败**
```
错误: Python 下载失败
```

**解决**:
- 检查网络连接
- 访问 https://github.com/indygreg/python-build-standalone/releases
- 手动下载 tarball 到构建目录
- 重新运行脚本（会使用本地文件）

**问题 2: pip install 失败**
```
错误: 某个依赖安装失败
```

**解决**:
```bash
# 手动测试
build_portable/ByteFlow.app/Contents/Frameworks/Python.framework/bin/python3 -m pip install fastapi -v

# 检查网络/pypi 连接
# 考虑使用国内镜像（临时）:
# pip install -i https://pypi.tuna.tsinghua.edu.cn/simple fastapi
```

**问题 3: hdiutil 失败**
```
hdiutil: create failed - Resource busy
```

**解决**:
```bash
# 卸载所有挂载的卷
hdiutil detach "/Volumes/ByteFlow Installer" -force

# 清理临时文件
rm -f temp.dmg

# 重新运行
./build_portable_dmg.sh
```

### 运行失败

**问题 1: "应用包损坏"**
```
未找到内嵌的 Python 运行时
```

**原因**: Python 解压失败或路径错误

**解决**:
```bash
# 验证 Python 存在
ls -la /Applications/ByteFlow.app/Contents/Frameworks/Python.framework/bin/python3

# 重新下载 DMG
```

**问题 2: 服务启动失败**
```
collector.py 或 api.py 无法运行
```

**解决**:
```bash
# 查看日志
cat ~/Library/Application\ Support/ByteFlow/logs/collector.log
cat ~/Library/Application\ Support/ByteFlow/logs/api.log

# 手动测试
/Applications/ByteFlow.app/Contents/Frameworks/Python.framework/bin/python3 \
  /Applications/ByteFlow.app/Contents/Resources/collector.py
```

**问题 3: 依赖缺失**
```
ModuleNotFoundError: No module named 'fastapi'
```

**原因**: 构建时依赖未正确安装

**解决**:
- 重新构建 DMG
- 验证构建日志中 pip install 成功

## 📊 性能和大小优化

### 当前大小

| 组件 | 大小 | 优化潜力 |
|------|------|---------|
| Python runtime | 50MB | 中 |
| 标准库 | 30MB | 高 |
| site-packages | 20MB | 中 |
| 应用代码 | 1MB | 低 |

### 可选优化（未实现）

1. **精简标准库**:
   - 移除未使用模块（test, tkinter, idlelib, etc.）
   - 节省 ~10-15MB

2. **编译 .pyc 并删除 .py**:
   ```bash
   python -m compileall -b site-packages/
   find site-packages/ -name '*.py' -delete
   ```
   - 节省 ~5-10MB

3. **使用 UPX 压缩二进制**:
   ```bash
   upx --best Python.framework/bin/python3
   ```
   - 节省 ~10-20MB（可能影响签名）

4. **移除调试符号**:
   ```bash
   strip -S Python.framework/bin/python3
   ```
   - 节省 ~5MB

**权衡**: 优化增加构建复杂度，可能影响兼容性。当前大小（~150-200MB）可接受。

## 🔒 代码签名

### 签名 bundled Python 和 app

```bash
# 签名 Python 可执行文件
codesign --force --sign "Developer ID Application: Your Name" \
  ByteFlow.app/Contents/Frameworks/Python.framework/bin/python3

# 签名所有 .so 文件
find ByteFlow.app/Contents/Frameworks/Python.framework -name '*.so' -exec \
  codesign --force --sign "Developer ID Application: Your Name" {} \;

# 签名整个 .app（deep sign）
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name" \
  --entitlements ByteFlow.entitlements \
  ByteFlow.app

# 验证
codesign --verify --deep --verbose=2 ByteFlow.app

# 公证
xcrun notarytool submit ByteFlow-v2.0-arm64.dmg \
  --apple-id your@email.com \
  --team-id TEAMID \
  --wait

# 装订
xcrun stapler staple ByteFlow.app
xcrun stapler staple ByteFlow-v2.0-arm64.dmg
```

**注意**: 需要付费 Apple Developer 账号。

## 📝 分发清单

### 文件准备

- [ ] `ByteFlow-v2.0-arm64.dmg` (Apple Silicon)
- [ ] `ByteFlow-v2.0-x86_64.dmg` (Intel)
- [ ] README.md（包含下载和安装说明）
- [ ] 使用说明.txt（DMG 内已包含）

### 发布平台

- GitHub Releases
- 官方网站下载页
- 镜像站（国内用户）

### 用户文档

在 README 中说明:
1. **架构选择**:
   - "M1/M2/M3 Mac 用户请下载 arm64 版本"
   - "Intel Mac 用户请下载 x86_64 版本"

2. **安装步骤**:
   - 双击 DMG
   - 拖拽到 Applications
   - 右键 > 打开（Gatekeeper）

3. **系统要求**:
   - macOS 10.14+
   - 无需 Python
   - 磁盘空间 ~200MB

4. **权限配置**:
   - 终端完全磁盘访问

5. **卸载方法**

## 🎯 最佳实践

### 构建

1. **在干净的 Mac 上构建**（避免环境污染）
2. **验证 Python tarball 的 SHA256**（安全性）
3. **测试每个构建**（不要直接发布）
4. **保留构建日志**（排查问题）

### 发布

1. **提供两个架构的 DMG**
2. **在 Release Notes 中说明架构选择**
3. **提供 SHA256 校验和**
4. **包含详细安装说明**

### 用户支持

1. **常见问题 FAQ**（Gatekeeper, 权限, 架构错误）
2. **日志收集指南**（`~/Library/Application Support/ByteFlow/logs/`）
3. **反馈渠道**（GitHub Issues）

## 🚀 与标准版本对比

| 使用场景 | 推荐版本 |
|---------|---------|
| 生产环境分发 | ✅ 便携式 DMG |
| 企业内网部署（无外网） | ✅ 便携式 DMG |
| 普通用户（无技术背景） | ✅ 便携式 DMG |
| 开发测试 | 标准 DMG 或 Install.command |
| 贡献者本地开发 | 手动运行 start.sh |

---

**总结**: 便携式 DMG 提供完全自包含的分发方式，适合生产环境和最终用户。虽然文件较大（~150-200MB），但提供了最佳的开箱即用体验。
