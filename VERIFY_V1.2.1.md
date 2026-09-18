# ByteFlow v1.2.1 验证清单

## 🔧 已应用的修复（从用户提供的 tarball）

### 1. ✅ Collector 准确性修复 (CRITICAL)

**问题**: `parse_nettop_output` 错误地将 nettop 连接行（如 `udp4 *:5353<->*:*`, `tcp4 ...<->...`）识别为应用。

**修复** (`packaging/src/collector.py` 和 `/workspace/collector.py`):
- 在进程聚合逻辑中，跳过任何第一字段包含 `<->` 的行
- 显式跳过 `mDNSResponder` 和 `*:5353` 噪音
- 采用双 nettop 调用策略:
  - `nettop -P -n -L 1 -J bytes_in,bytes_out -x`: 进程汇总流量
  - `nettop -n -L 1 -x -J bytes_in,bytes_out` (不带 `-P`): 连接级 IP 详情

**验证点**:
- [ ] 概览中无 `udp4 *:5353<->*:*` 或类似虚假应用
- [ ] 概览中无 `tcp4 ...<->...` 虚假应用
- [ ] 流量统计准确（不再包含连接行的错误累加）

---

### 2. ✅ 离线图表支持

**问题**: 模态窗口中的 Chart.js 从 CDN 加载，在打包后的 webview 中失败（离线环境）。

**修复**:
- **`packaging/src/web/vendor/chart.umd.min.js`**: 添加本地 Chart.js 文件（205KB）
- **`packaging/src/web/index.html`**: 修改为 `<script src="/vendor/chart.umd.min.js"></script>`
- **`packaging/src/api.py`**: 添加 `app.mount("/vendor", StaticFiles(directory=os.path.join(_web_dir, "vendor")), name="vendor")`

**验证点**:
- [ ] 打开应用后，点击任意应用打开模态
- [ ] 模态窗口中的历史图表正常显示（24h/7d/30d）
- [ ] 浏览器控制台无 Chart.js 加载错误
- [ ] 离线环境下图表仍然工作

---

### 3. ✅ 应用图标

**问题**: ByteFlow.app 在 Dock 和 Finder 中显示默认图标。

**修复**:
- **`packaging/src/assets/AppIcon.png`**: 256x256 PNG 图标（25.8KB）
- **`packaging/src/assets/icon.png`**: 同样的图标
- **`packaging/build_universal_dmg.command`**: 
  - 使用 `sips` 生成多尺寸 `.iconset`（16, 32, 128, 256, 512 及 @2x）
  - 使用 `iconutil` 转换为 `.icns`
  - 复制到 `ByteFlow.app/Contents/Resources/AppIcon.icns`
  - `Info.plist` 中设置 `CFBundleIconFile = AppIcon`

**验证点**:
- [ ] 在 Finder 中查看 Applications/ByteFlow.app，图标正确显示
- [ ] 在 Dock 中运行 ByteFlow，图标正确显示
- [ ] 在 Activity Monitor 中查看进程，图标正确显示

---

### 4. ✅ DMG 体积大幅优化

**问题**: 通用 DMG 大小 ~75MB+，主要由于完整 Python 构建和未清理的缓存/测试文件。

**优化** (`packaging/build_universal_dmg.command`):
1. **使用精简 Python**: 
   - 从 `install_only.tar.gz` 改为 `install_only_stripped.tar.gz`
   - Python 版本: 3.12.14 (python-build-standalone 20260901)
2. **pip 安装优化**:
   - `pip install --no-cache-dir`
   - 安装后卸载 pip/setuptools/wheel: `pip uninstall -y pip setuptools wheel`
3. **清理缓存和测试**:
   - `find ... -name '__pycache__' -prune -exec rm -rf {} +`
   - `find ... -name 'tests' -prune -exec rm -rf {} +`
   - `find ... -name 'test' -prune -exec rm -rf {} +`
   - `rm -rf .../share .../ensurepip`
4. **双架构重复清理**: 对 arm64 和 x86_64 Python 都执行清理

**预期结果**:
- DMG 大小: **~40-60MB**（从 ~75MB+ 降低）
- 构建时间: 首次 ~10-15 分钟，缓存后 ~5-8 分钟

**验证点**:
- [ ] 构建后的 `ByteFlow-universal.dmg` 大小在 40-60MB 范围内
- [ ] DMG 内的 ByteFlow.app 仍然包含所有必需依赖
- [ ] 运行时功能完整（pywebview, fastapi, uvicorn, aiosqlite, rumps, pyobjc）
- [ ] 无运行时错误（缺少模块等）

---

## 📋 文件清单

### 已更新文件
1. `packaging/src/collector.py` - Collector 准确性修复
2. `packaging/src/api.py` - `/vendor` StaticFiles 挂载
3. `packaging/src/web/index.html` - 本地 Chart.js 引用
4. `packaging/src/web/vendor/chart.umd.min.js` - 本地 Chart.js 文件（新增）
5. `packaging/src/assets/AppIcon.png` - 应用图标（新增）
6. `packaging/src/assets/icon.png` - 应用图标副本（新增）
7. `packaging/build_universal_dmg.command` - 优化和图标生成
8. `collector.py` - 根目录 collector 同步修复
9. `build_universal_dmg.command` - 根目录包装器（新增）
10. `README.md` - 更新 DMG 大小和 v1.2.1 修复说明
11. `.github/workflows/release.yml` - 更新 release notes
12. `RELEASE_GUIDE.md` - 发布指南（新增）

### 已删除文件
无

---

## 🚀 构建和发布

### 本地构建（macOS）

```bash
cd /workspace
./build_universal_dmg.command
```

**预期输出**: `~/Desktop/ByteFlow-universal.dmg` (~40-60MB)

### GitHub Actions 自动构建

**方法 1: Git Tag**
```bash
git tag v1.2.1
git push origin v1.2.1
```

**方法 2: 手动触发**
1. 访问 https://github.com/Freegxx/byteflow/actions/workflows/release.yml
2. 点击 "Run workflow"
3. 输入版本号: `v1.2.1`
4. 点击 "Run workflow"

**预期**: 
- 自动构建 Universal DMG
- 创建 GitHub Release: https://github.com/Freegxx/byteflow/releases/tag/v1.2.1
- 上传 `ByteFlow-universal.dmg` 和 SHA256 校验文件

---

## ✅ 测试清单（macOS 必测）

### 安装测试
- [ ] 下载 `ByteFlow-universal.dmg`
- [ ] 双击打开 DMG
- [ ] 将 `ByteFlow.app` 拖到 Applications
- [ ] 右键点击 → 打开（绕过 Gatekeeper）
- [ ] 原生桌面窗口自动打开（**不打开浏览器**）
- [ ] 窗口标题显示 "ByteFlow"
- [ ] 应用图标在 Dock 中正确显示

### 功能测试
- [ ] 概览页面显示应用列表（无 `udp4`/`tcp4` 虚假应用）
- [ ] 搜索框过滤正常工作
- [ ] 点击任意应用打开模态窗口
- [ ] 模态中显示 3 个使用量卡片（24h/7d/30d）
- [ ] 模态中的历史图表正确显示（Chart.js 加载成功）
- [ ] 切换 24h/7d/30d 时段，图表更新
- [ ] IP 列表显示该应用连接的远程 IP
- [ ] 自动刷新功能正常（选择间隔后生效）
- [ ] 关闭窗口后，后台服务自动停止（`ps aux | grep collector` 无残留）

### 架构测试
- [ ] **Apple Silicon (M1/M2/M3/M4)**: 正常运行
- [ ] **Intel Mac**: 正常运行（如有条件）

### 性能测试
- [ ] 采集器 CPU 使用率 < 1%
- [ ] 数据库大小合理（< 100MB，运行一天后）
- [ ] UI 响应流畅

---

## 🐛 已知问题

### 非问题
- **菜单栏应用（可选）**: 在 Python 3.9 环境下 `rumps` 安装可能失败，构建脚本将其视为可选组件继续
- **未公证**: DMG 未经过 Apple 公证，首次打开需要右键 → 打开

### 待观察
- 在非常老的 macOS 版本（< 10.14）上可能不兼容
- pywebview 依赖 WebKit，某些老系统可能有限制

---

## 📝 Release Notes（v1.2.1）

### 🐛 Critical Fixes

1. **数据采集准确性修复 (CRITICAL)**
   - 修复了错误地将 nettop 连接行（如 `udp4 *:5353<->*:*`）识别为应用的问题
   - 这导致"虚假应用"出现在概览中并产生大量错误的流量统计
   - 现已正确跳过包含 `<->` 的连接行，只解析进程汇总数据
   - 过滤 mDNSResponder 和 `*:5353` 噪音

2. **离线图表支持**
   - 修复了模态窗口中图表无法显示的问题
   - 从 CDN 改为本地 `/vendor/chart.umd.min.js` 文件
   - 确保打包应用在离线环境下正常工作

3. **应用图标**
   - 添加 `AppIcon.png` + `.icns` 生成
   - 在 Dock 和 Finder 中显示 ByteFlow 自定义图标

4. **DMG 体积大幅优化**
   - 从 ~75MB+ 降至 **~40-60MB**
   - 使用 `install_only_stripped` Python 构建
   - 清理 `__pycache__`, `tests`, pip 缓存

### 🔧 Technical Improvements

- 采集器使用双 nettop 调用：`nettop -P` 用于进程汇总，单独调用用于 IP 连接详情
- API `/vendor` 路径解析改为相对 `api.py` 位置，支持打包环境
- 构建脚本自动化优化流程（find/rm + uninstall pip 后保留运行时）

---

## 🔗 资源链接

- **PR**: https://github.com/Freegxx/byteflow/pull/1
- **Release** (待创建): https://github.com/Freegxx/byteflow/releases/tag/v1.2.1
- **主分支**: `cursor/byteflow-macos-network-monitor-9efb`
- **构建脚本**: `packaging/build_universal_dmg.command`
- **发布指南**: `RELEASE_GUIDE.md`

---

## 👨‍💻 开发者备注

如需在 Mac 上手动构建和测试：

```bash
# 克隆仓库
git clone https://github.com/Freegxx/byteflow.git
cd byteflow
git checkout cursor/byteflow-macos-network-monitor-9efb

# 构建 Universal DMG
./build_universal_dmg.command

# 输出: ~/Desktop/ByteFlow-universal.dmg
# 大小应为 ~40-60MB

# 手动测试
open ~/Desktop/ByteFlow-universal.dmg
# 拖到 Applications，右键打开，验证上述测试清单
```

如遇到问题，请检查：
1. 是否在 macOS 上运行（Linux/Windows 无法构建 DMG）
2. 网络连接是否正常（需要下载 Python 和依赖）
3. 磁盘空间是否充足（需要 ~500MB 临时空间）
4. Xcode Command Line Tools 是否安装（`xcode-select --install`）

---

**验证完成后，请在 GitHub Release 页面标注 "Verified on macOS [版本] [架构]"**
