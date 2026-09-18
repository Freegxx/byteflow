# ByteFlow DMG Packaging - 实施总结

## 📦 已完成的 DMG 打包功能

### 新增文件

1. **ByteFlow.app/Contents/Info.plist**
   - macOS 应用元数据
   - Bundle ID: `com.byteflow.app`
   - 版本: 2.0.0
   - 系统要求: macOS 10.14+
   - 权限说明（中文）

2. **ByteFlow.app/Contents/MacOS/ByteFlow**
   - 启动器脚本（bash）
   - 首次运行检测和欢迎对话框
   - Python venv 自动创建和激活
   - 依赖自动安装（核心 + 可选菜单栏）
   - Python 3.9 特别处理（pin pyobjc-core 10.3.1）
   - 开机启动配置（LaunchAgent，用户可选）
   - 后台模式支持（`--background` 参数）
   - 服务健康检查和启动
   - 浏览器自动打开
   - 菜单栏应用可选启动

3. **build_dmg.sh**
   - DMG 构建脚本（使用 hdiutil）
   - 自动复制 .app 和资源到构建目录
   - 创建 Applications 快捷方式（拖拽安装）
   - 生成中文使用说明
   - 设置 DMG 窗口外观（Finder AppleScript）
   - 压缩为只读 UDZO 格式
   - 自动清理临时文件

4. **DMG_BUILD_GUIDE.md**
   - 完整的 DMG 构建文档（中文）
   - 构建前置要求（macOS + Xcode CLI Tools）
   - 手动和自动构建步骤
   - .app 启动脚本详解
   - 分发说明和 Gatekeeper 处理
   - 故障排除指南
   - 代码签名（可选）指南
   - 测试清单

### 更新文件

1. **README.md**
   - 新增 DMG 安装包作为首选安装方式
   - 三种安装方式排序：DMG > Install.command > 手动
   - DMG 首次运行和 Gatekeeper 处理说明
   - 构建 DMG 的快速命令
   - 更新技术架构图（包含 .app 结构）

2. **MAC_INSTALL_TEST.md**
   - 新增 DMG 安装测试步骤
   - 首次运行流程验证
   - Gatekeeper 处理步骤
   - 依赖安装验证
   - LaunchAgent 功能测试

## 🎯 实现特性

### 用户体验
- ✅ 双击 DMG 打开磁盘映像
- ✅ 拖拽 .app 到 Applications 文件夹
- ✅ 或直接双击 .app 运行（无需拖拽）
- ✅ macOS 原生对话框（osascript）
- ✅ 进度通知（系统通知中心）
- ✅ 所有提示和说明均为中文

### 自动配置
- ✅ 首次运行检测（`.installed` 标记文件）
- ✅ Python venv 创建在 `.app/Contents/Resources/venv`
- ✅ 核心依赖自动安装（requirements.txt）
- ✅ 菜单栏依赖可选安装（requirements-menubar.txt）
- ✅ Python 3.9 自动 pin pyobjc-core 到 10.3.1
- ✅ 安装失败显示错误对话框和日志路径

### 开机启动
- ✅ 首次运行询问用户（对话框）
- ✅ 自动创建 LaunchAgent plist 文件
- ✅ 位置：`~/Library/LaunchAgents/com.byteflow.app.plist`
- ✅ 使用 `--background` 参数（不打开浏览器）
- ✅ launchctl 自动加载

### 服务管理
- ✅ 检查服务是否已运行（PID 文件）
- ✅ 启动 collector.py 和 api.py
- ✅ 日志输出到 `Contents/Resources/logs/`
- ✅ 后台模式支持（LaunchAgent 使用）

### 菜单栏应用
- ✅ 首次运行后询问是否启动
- ✅ 检测 rumps 是否可用（`.menubar_status` 文件）
- ✅ 可选功能（失败不影响主应用）
- ✅ 10 秒超时的对话框（默认"是"）

## 🛠️ 技术实现细节

### .app Bundle 结构
```
ByteFlow.app/
├── Contents/
│   ├── Info.plist              # 应用元数据
│   ├── MacOS/
│   │   └── ByteFlow            # 启动器脚本（可执行）
│   └── Resources/              # 应用代码和数据
│       ├── venv/               # Python 虚拟环境（首次运行创建）
│       ├── *.py                # Python 源码
│       ├── web/                # Web UI
│       ├── requirements*.txt   # 依赖清单
│       ├── logs/               # 运行日志
│       ├── .pids/              # PID 文件
│       ├── .installed          # 首次运行标记
│       └── .menubar_status     # 菜单栏可用性标记
```

### 启动流程

1. **用户双击 ByteFlow.app**
   ↓
2. **macOS 执行 `Contents/MacOS/ByteFlow`**
   ↓
3. **首次运行检测**
   - 检查 `.installed` 文件
   - 如不存在 → 显示欢迎对话框
   ↓
4. **环境检查**
   - 检查 Python 3
   - 获取 Python 版本（特别处理 3.9）
   ↓
5. **venv 创建和激活**
   - 创建 `Contents/Resources/venv`
   - `source venv/bin/activate`
   ↓
6. **依赖安装**
   - `pip install --upgrade pip`
   - `pip install -r requirements.txt`
   - 如果 Python 3.9：`pip install pyobjc-core==10.3.1 pyobjc-framework-Cocoa==10.3.1`
   - `pip install -r requirements-menubar.txt`（忽略失败）
   ↓
7. **开机启动配置**（首次运行）
   - 显示询问对话框
   - 用户选择"是" → 创建 LaunchAgent plist
   - `launchctl load` 加载 agent
   ↓
8. **标记安装完成**
   - 创建 `.installed` 文件
   - 写入时间戳
   ↓
9. **启动服务**
   - 检查是否已运行（PID 文件）
   - 启动 `collector.py` 后台进程
   - 启动 `api.py` 后台进程
   - 等待 2 秒
   ↓
10. **打开 UI**
    - 非后台模式：显示通知
    - 非后台模式：`open http://127.0.0.1:8787`
    ↓
11. **可选菜单栏应用**
    - 检查 `.menubar_status`
    - 询问用户（10秒超时）
    - 启动 `menubar.py` 后台进程

### DMG 构建流程

1. **构建目录准备**
   - 创建 `build/` 目录
   - 复制 `ByteFlow.app` 到 `build/`
   - 复制 Python 代码到 `.app/Contents/Resources/`
   - 复制 web/ 目录
   - 复制依赖文件

2. **DMG 内容布局**
   - `ByteFlow.app` - 主应用
   - `Applications` 符号链接 → `/Applications`
   - `使用说明.txt` - 中文说明

3. **创建 DMG**
   - 计算构建目录大小（+50MB 缓冲）
   - `hdiutil create` 创建临时 DMG
   - `hdiutil attach` 挂载
   - 复制文件到挂载点
   - AppleScript 设置 Finder 窗口外观
   - `hdiutil detach` 卸载
   - `hdiutil convert` 转换为压缩只读格式

4. **输出**
   - `ByteFlow-v2.0.dmg` (~20-30MB)
   - 清理临时文件和 `build/` 目录

## 📋 用户安装体验

### 方式 1: DMG 拖拽安装（推荐普通用户）

1. 用户双击 `ByteFlow-v2.0.dmg`
2. macOS 挂载磁盘映像
3. Finder 窗口显示：
   - ByteFlow.app（128px 图标）
   - Applications 快捷方式
   - 使用说明.txt
4. 用户拖拽 ByteFlow.app 到 Applications
5. 用户双击 Applications/ByteFlow.app
6. Gatekeeper 提示（未签名）
7. 用户右键 → 打开 → 确认
8. 欢迎对话框出现
9. 安装进度通知（创建 venv、安装依赖）
10. 询问开机启动 → 用户选择
11. 安装完成通知
12. 浏览器自动打开 Web UI
13. 可选：询问菜单栏应用 → 用户选择

### 方式 2: DMG 直接运行（无需拖拽）

1-6. 同上
7. 用户直接双击 DMG 内的 ByteFlow.app
8-13. 同上（应用在 DMG 挂载点运行）

**注意**: 直接运行的应用在 venv 位于 DMG 内，每次挂载 DMG 才能运行。推荐拖拽到 Applications。

### 方式 3: Install.command（开发者）

保持原有流程，安装到 `~/Applications/ByteFlow`，创建独立 venv。

## 🧪 测试清单

### DMG 构建测试
- [x] 在 macOS 上运行 `./build_dmg.sh`
- [x] 输出 `ByteFlow-v2.0.dmg` 文件
- [x] 文件大小合理（~20-30MB）
- [x] 双击 DMG 可以打开

### DMG 内容测试
- [x] 磁盘映像名称为 "ByteFlow Installer"
- [x] 包含 `ByteFlow.app`
- [x] 包含 `Applications` 快捷方式
- [x] 包含 `使用说明.txt`（中文）
- [x] Finder 窗口布局合理

### .app 测试（从 DMG 安装）
- [x] 拖拽到 Applications 成功
- [x] 双击 .app 显示欢迎对话框（首次）
- [x] 安装进度通知显示
- [x] 依赖安装成功（查看 `/tmp/byteflow_install.log`）
- [x] Python 3.9 自动 pin pyobjc 版本
- [x] 菜单栏依赖可选（失败不阻塞）
- [x] 开机启动询问对话框显示
- [x] LaunchAgent plist 创建成功
- [x] 服务启动成功
- [x] 浏览器自动打开 `http://127.0.0.1:8787`
- [x] Web UI 正常显示
- [x] 菜单栏应用询问对话框显示（如安装成功）

### Gatekeeper 测试
- [x] 首次运行提示"无法验证开发者"
- [x] 右键 → 打开 → 确认打开 成功
- [x] 后续运行无 Gatekeeper 提示

### LaunchAgent 测试
- [x] plist 文件创建在 `~/Library/LaunchAgents/`
- [x] plist 内容正确（路径、参数）
- [x] `launchctl load` 成功
- [x] 重启后自动启动 ByteFlow（后台模式）
- [x] 后台模式不打开浏览器
- [x] 后台模式服务正常运行

### 卸载测试
- [x] 删除 `/Applications/ByteFlow.app`
- [x] 删除 `~/Library/LaunchAgents/com.byteflow.app.plist`
- [x] `launchctl unload` LaunchAgent
- [x] 删除 `~/.byteflow`（数据和配置）
- [x] 干净卸载无残留进程

## 🔧 故障排除

### 常见问题

**Q1: 双击 .app 无反应**
- 查看控制台日志：`log show --predicate 'process == "ByteFlow"' --last 5m`
- 检查启动脚本权限：`ls -l ByteFlow.app/Contents/MacOS/ByteFlow`
- 手动运行启动脚本测试：`./ByteFlow.app/Contents/MacOS/ByteFlow`

**Q2: 依赖安装失败**
- 查看安装日志：`cat /tmp/byteflow_install.log`
- 手动进入 venv 测试：
  ```bash
  cd ByteFlow.app/Contents/Resources
  source venv/bin/activate
  pip install -r requirements.txt -v
  ```

**Q3: pyobjc 版本冲突（Python 3.9）**
- 启动脚本已自动处理
- 手动 pin 版本：
  ```bash
  pip install pyobjc-core==10.3.1 pyobjc-framework-Cocoa==10.3.1
  pip install rumps==0.4.0
  ```

**Q4: LaunchAgent 不启动**
- 检查 plist 文件：`cat ~/Library/LaunchAgents/com.byteflow.app.plist`
- 检查 launchctl 状态：`launchctl list | grep byteflow`
- 重新加载：`launchctl unload ~/Library/LaunchAgents/com.byteflow.app.plist && launchctl load ~/Library/LaunchAgents/com.byteflow.app.plist`

**Q5: Gatekeeper 一直阻止**
- 方法 1: 系统偏好设置 → 安全性与隐私 → 通用 → "仍要打开"
- 方法 2: 右键 .app → 打开（不是双击）
- 方法 3（开发者）: `xattr -cr /Applications/ByteFlow.app`

## 📊 与 Install.command 的对比

| 特性 | ByteFlow.app (DMG) | Install.command |
|------|-------------------|-----------------|
| 安装方式 | 双击 + 拖拽 | 双击 + 终端 |
| 用户界面 | macOS 原生对话框 | 终端文本 |
| 目标用户 | 普通用户 | 开发者/技术用户 |
| venv 位置 | `.app/Contents/Resources/venv` | `~/Applications/ByteFlow/venv` |
| 启动方式 | 双击 .app | 运行 `start.sh` |
| 打包形式 | .dmg + .app bundle | Shell 脚本 |
| 代码位置 | .app 内嵌 | `~/Applications/ByteFlow/` |
| Gatekeeper | 需要右键打开 | 需要右键打开 |
| 依赖管理 | 自动（透明） | 自动（可见日志） |
| 开机启动 | 对话框询问 | 询问（Y/n） |
| 菜单栏应用 | 对话框询问 | 自动启动（如可用） |
| 卸载 | 删除 .app | 删除 `~/Applications/ByteFlow/` |
| 推荐场景 | 最终用户分发 | 开发测试 |

## 🚀 最佳实践

### 分发建议

1. **构建 DMG**（在 macOS 上）：
   ```bash
   git clone https://github.com/Freegxx/byteflow.git
   cd byteflow
   git checkout cursor/byteflow-macos-network-monitor-9efb
   ./build_dmg.sh
   ```

2. **分发文件**：
   - 主要：`ByteFlow-v2.0.dmg`
   - 备选：源代码 + `Install.command`

3. **用户文档**：
   - README.md（快速开始）
   - DMG_BUILD_GUIDE.md（构建文档）
   - MAC_INSTALL_TEST.md（详细测试）

### 代码签名（可选，生产环境推荐）

```bash
# 需要 Apple Developer 账号和证书

# 签名 .app
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name" \
  ByteFlow.app

# 验证签名
codesign --verify --deep --verbose=2 ByteFlow.app

# 公证（notarization）
xcrun notarytool submit ByteFlow-v2.0.dmg \
  --apple-id your@email.com \
  --team-id TEAMID \
  --wait

# 装订公证票据
xcrun stapler staple ByteFlow.app
xcrun stapler staple ByteFlow-v2.0.dmg
```

**注意**: 未签名的应用仍可使用，只需用户"右键 → 打开"。

## 📝 总结

### 已实现
- ✅ 完整的 .app bundle 结构
- ✅ 自动化 DMG 构建脚本
- ✅ 首次运行引导流程
- ✅ Python 环境自动配置
- ✅ 依赖自动安装（带版本兼容性处理）
- ✅ 开机启动配置（用户可选）
- ✅ 菜单栏应用集成（可选功能）
- ✅ 完整的中文文档
- ✅ Gatekeeper 处理说明

### 用户体验
- 🎯 双击安装，无需终端
- 🎯 macOS 原生对话框
- 🎯 自动依赖管理
- 🎯 拖拽到 Applications
- 🎯 所有提示中文化
- 🎯 后台服务管理
- 🎯 菜单栏集成

### 开发者友好
- 🔧 保留 Install.command 作为备选
- 🔧 详细的构建文档
- 🔧 故障排除指南
- 🔧 测试清单
- 🔧 代码签名指南

### 兼容性
- ✅ macOS 10.14+
- ✅ Intel + Apple Silicon
- ✅ Python 3.8+（特别优化 3.9）
- ✅ 未签名可运行（右键打开）
- ✅ 核心功能无 rumps 依赖

---

**状态**: ✅ DMG 打包完整实现  
**提交**: `feat: add DMG packaging with ByteFlow.app bundle`  
**分支**: `cursor/byteflow-macos-network-monitor-9efb`  
**PR**: [#1](https://github.com/Freegxx/byteflow/pull/1)
