# ByteFlow 通用 DMG 构建指南

## 概述

通用 DMG 包含 **arm64 + x86_64 双架构** Python 运行时，启动器自动检测并使用匹配的架构。

**优势**: 用户只需下载一个 DMG，适用于所有 Mac（Apple Silicon 和 Intel）。

---

## 🎯 架构方案

### 方案选择: 双 Python 嵌入

**实现**: 在 `ByteFlow.app/Contents/Frameworks` 中嵌入两套完整的 Python 运行时：
- `Python-arm64.framework/` - Apple Silicon Python 3.11.9
- `Python-x86_64.framework/` - Intel Mac Python 3.11.9

**启动器逻辑**:
```bash
CURRENT_ARCH=$(uname -m)

if [[ "$CURRENT_ARCH" == "arm64" ]]; then
    BUNDLED_PYTHON="$FRAMEWORKS/Python-arm64.framework/bin/python3"
elif [[ "$CURRENT_ARCH" == "x86_64" ]]; then
    BUNDLED_PYTHON="$FRAMEWORKS/Python-x86_64.framework/bin/python3"
fi

exec "$BUNDLED_PYTHON" desktop.py
```

**为什么不用 lipo/Universal2**:
- ❌ Python .so 文件数百个，lipo 每个文件复杂度高
- ❌ 某些 .so 可能不支持 fat binary
- ❌ pywebview 的 C 扩展处理困难
- ✅ 双嵌入方案简单可靠，磁盘便宜（~300MB）

---

## 🔧 构建脚本

### build_universal_dmg.command

**功能**:
1. ✅ 下载 arm64 + x86_64 Python from python-build-standalone
2. ✅ 解压到 `Python-arm64.framework` 和 `Python-x86_64.framework`
3. ✅ pip install 依赖到**每个** Python（pywebview, fastapi, uvicorn, aiosqlite, rumps, pyobjc）
4. ✅ 复制应用代码到 Resources
5. ✅ 创建通用启动器（架构检测）
6. ✅ hdiutil 创建 `ByteFlow-universal.dmg`

**用法**:
```bash
./build_universal_dmg.command
# 输出: ByteFlow-universal.dmg (~300-350MB)
```

**构建时间**:
- 首次: ~10-15 分钟（下载两个 Python tarballs + 安装依赖两次）
- 后续: ~5-8 分钟（使用缓存）

---

## 📦 DMG 结构

```
ByteFlow-universal.dmg
└── ByteFlow.app/
    └── Contents/
        ├── MacOS/
        │   └── ByteFlow          # 通用启动器（架构检测）
        ├── Frameworks/
        │   ├── Python-arm64.framework/
        │   │   ├── bin/python3   # Apple Silicon Python
        │   │   └── lib/python3.11/site-packages/
        │   │       ├── fastapi/
        │   │       ├── uvicorn/
        │   │       ├── pywebview/
        │   │       └── ...
        │   └── Python-x86_64.framework/
        │       ├── bin/python3   # Intel Mac Python
        │       └── lib/python3.11/site-packages/
        │           ├── fastapi/
        │           ├── uvicorn/
        │           ├── pywebview/
        │           └── ...
        ├── Resources/
        │   ├── desktop.py
        │   ├── collector.py
        │   ├── api.py
        │   ├── web/
        │   └── ...
        └── Info.plist
```

---

## 🚀 用户安装体验

### 安装步骤（所有 Mac）

1. 下载 `ByteFlow-universal.dmg`
2. 双击打开
3. 拖拽 `ByteFlow.app` 到 Applications
4. 右键 > 打开（Gatekeeper）
5. 原生桌面窗口打开

### 首次运行

**欢迎对话框**:
```
欢迎使用 ByteFlow 网络流量监控！

这是通用版本，支持 Apple Silicon 和 Intel Mac。

检测到架构: arm64 (Apple Silicon)
或: x86_64 (Intel)

点击"继续"开始首次配置...
```

**后台流程**:
1. 启动器检测架构（`uname -m`）
2. 选择对应的 Python（arm64 或 x86_64）
3. 启动 desktop.py 创建原生窗口
4. 自动启动 collector + API

**用户无感知**: 不需要知道架构，不需要选择，自动正确。

---

## 🧪 测试验证

### 构建测试

```bash
# 在任意 Mac 上构建
./build_universal_dmg.command

# 验证输出
ls -lh ByteFlow-universal.dmg

# 验证双架构 Python
ls -la build_universal/ByteFlow.app/Contents/Frameworks/
# 应该看到:
# Python-arm64.framework/
# Python-x86_64.framework/

# 验证依赖（arm64）
build_universal/ByteFlow.app/Contents/Frameworks/Python-arm64.framework/bin/python3 \
  -c "import pywebview; print('pywebview OK')"

# 验证依赖（x86_64）
build_universal/ByteFlow.app/Contents/Frameworks/Python-x86_64.framework/bin/python3 \
  -c "import pywebview; print('pywebview OK')"
```

### 安装测试（Apple Silicon Mac）

```bash
# 安装
# 1. 双击 ByteFlow-universal.dmg
# 2. 拖拽到 Applications
# 3. 右键 > 打开

# 验证架构选择
# 打开后查看日志:
cat ~/Library/Application\ Support/ByteFlow/.installed
# 应该显示:
# Architecture: arm64

# 验证运行的 Python
ps aux | grep python
# 应该显示:
# .../Python-arm64.framework/bin/python3 desktop.py
```

### 安装测试（Intel Mac）

同上，验证应该显示 `Architecture: x86_64` 和 `Python-x86_64.framework`。

---

## 📊 文件大小

| 组件 | arm64 | x86_64 | 总计 |
|------|-------|--------|------|
| Python runtime | ~50MB | ~50MB | ~100MB |
| Python 标准库 | ~30MB | ~30MB | ~60MB |
| site-packages | ~20MB | ~20MB | ~40MB |
| 应用代码 | - | - | ~1MB |
| **DMG 总大小** | - | - | **~300-350MB** |

**对比**:
- 架构特定 DMG: ~150-200MB
- 通用 DMG: ~300-350MB
- 增加: ~100-150MB（可接受）

---

## 🌐 GitHub Actions 发布

### Workflow: `.github/workflows/release.yml`

**触发方式**:

1. **推送 tag**:
   ```bash
   git tag v2.0.0
   git push origin v2.0.0
   ```

2. **手动触发**:
   - GitHub → Actions → "Build and Release Universal DMG"
   - Click "Run workflow"
   - 输入版本号（如 v2.0.0）

**流程**:
1. Checkout 代码
2. 在 `macos-latest` runner 上运行 `build_universal_dmg.command`
3. 验证 DMG 创建成功
4. 计算 SHA256 校验和
5. 创建 GitHub Release
6. 上传 DMG + SHA256 文件

**输出**:
- GitHub Releases 页面自动创建新 release
- 附件: `ByteFlow-universal.dmg` + `ByteFlow-universal.dmg.sha256`
- Release notes 自动生成

### 手动发布（备选）

如果不使用 GitHub Actions:

```bash
# 1. 构建 DMG
./build_universal_dmg.command

# 2. 计算 SHA256
shasum -a 256 ByteFlow-universal.dmg > ByteFlow-universal.dmg.sha256

# 3. 创建 GitHub Release
gh release create v2.0.0 \
  --title "ByteFlow v2.0.0" \
  --notes "macOS 原生桌面应用 - 通用版本（Apple Silicon + Intel）" \
  ByteFlow-universal.dmg \
  ByteFlow-universal.dmg.sha256

# 4. 复制到用户 Mac（如需要）
cp ByteFlow-universal.dmg /Users/guxx/Developer/Personal/byteflow/
```

---

## 📋 维护清单

### 更新 Python 版本

编辑 `build_universal_dmg.command`:
```bash
PYTHON_VERSION="3.11.10"  # 更新版本
PYTHON_BUILD_STANDALONE_VERSION="20240815"  # 更新 release
```

### 更新依赖

编辑 `build_universal_dmg.command` 中的 requirements:
```bash
cat > "$BUILD_DIR/requirements_bundle.txt" <<EOF
fastapi==0.116.0     # 更新版本
uvicorn==0.31.0
pywebview==5.4
...
EOF
```

### 测试新版本

```bash
# 清理缓存
rm -f python-*.tar.gz

# 重新构建
./build_universal_dmg.command

# 测试两种架构（如果可能）
# - Apple Silicon Mac
# - Intel Mac（或 Rosetta 2）
```

---

## 🔍 故障排除

### 问题 1: Python 下载失败

```
错误: Python arm64 下载失败
```

**解决**:
- 检查网络连接
- 访问 https://github.com/indygreg/python-build-standalone/releases
- 验证 URL 和版本号
- 手动下载 tarball 到工作目录

### 问题 2: pip install 失败（某个架构）

```
警告: 菜单栏依赖 (arm64) 安装失败
```

**解决**:
```bash
# 手动测试
build_universal/ByteFlow.app/Contents/Frameworks/Python-arm64.framework/bin/python3 \
  -m pip install rumps -v

# 查看详细错误
# 可能原因: pyobjc 版本不兼容
```

### 问题 3: 启动器选择错误的架构

```
用户报告: Intel Mac 但使用了 arm64 Python
```

**诊断**:
```bash
# 查看安装标记
cat ~/Library/Application\ Support/ByteFlow/.installed

# 验证 uname -m
uname -m  # 应该是 arm64 或 x86_64

# 检查启动器逻辑
cat /Applications/ByteFlow.app/Contents/MacOS/ByteFlow | grep "uname -m"
```

### 问题 4: DMG 太大（超过 500MB）

**原因**: Python 包含调试符号或测试文件

**优化** (可选):
```bash
# 在 build_universal_dmg.command 中添加清理步骤:

# 清理 arm64
find "$PYTHON_ARM64_DIR" -name "*.pyc" -delete
find "$PYTHON_ARM64_DIR" -name "__pycache__" -type d -exec rm -rf {} +
find "$PYTHON_ARM64_DIR" -name "test" -type d -exec rm -rf {} +

# 清理 x86_64
find "$PYTHON_X86_64_DIR" -name "*.pyc" -delete
find "$PYTHON_X86_64_DIR" -name "__pycache__" -type d -exec rm -rf {} +
find "$PYTHON_X86_64_DIR" -name "test" -type d -exec rm -rf {} +
```

---

## 🆚 对比：架构特定 vs 通用

| 特性 | 架构特定 DMG | 通用 DMG |
|------|------------|---------|
| 文件数量 | 2 个 | 1 个 |
| DMG 大小 | ~150-200MB × 2 | ~300-350MB |
| 用户体验 | 需要选择架构 | 无需选择 |
| 下载便利性 | 中等 | 高 |
| 构建复杂度 | 简单 | 中等 |
| 维护成本 | 高（两个版本） | 低（一个版本） |
| 存储/带宽成本 | 高 | 中 |
| **推荐场景** | 技术用户 | **普通用户** ✅ |

**结论**: 通用 DMG 更适合生产分发。

---

## 📝 发布清单

### 准备发布

- [ ] 更新版本号（Info.plist, workflow）
- [ ] 测试所有功能（web UI, desktop, 菜单栏）
- [ ] 清理旧的构建产物
- [ ] 构建通用 DMG
- [ ] 在 Apple Silicon Mac 上测试
- [ ] 在 Intel Mac 上测试（或 Rosetta）
- [ ] 验证 Gatekeeper 处理
- [ ] 验证权限提示
- [ ] 计算 SHA256

### 发布到 GitHub

**方式 1: GitHub Actions** (推荐):
```bash
git tag v2.0.0
git push origin v2.0.0
# 自动触发 workflow，创建 release
```

**方式 2: 手动**:
```bash
./build_universal_dmg.command
shasum -a 256 ByteFlow-universal.dmg > ByteFlow-universal.dmg.sha256
gh release create v2.0.0 \
  --title "ByteFlow v2.0.0" \
  --notes-file RELEASE_NOTES.md \
  ByteFlow-universal.dmg \
  ByteFlow-universal.dmg.sha256
```

### 发布后

- [ ] 验证 Release 页面正确
- [ ] 下载测试（download + install）
- [ ] 更新 README 下载链接
- [ ] 发布 Release Notes（中英文）
- [ ] 通知用户

---

## 🎯 最佳实践

### 构建

1. **使用缓存**: 保留 `python-*.tar.gz` 以加速后续构建
2. **清理构建**: 每次发布前 `rm -rf build_universal`
3. **验证签名**: 可选，但推荐 `codesign` 整个 .app
4. **测试两架构**: 至少在一个架构上完整测试

### 发布

1. **语义化版本**: 遵循 `v<major>.<minor>.<patch>`
2. **Release Notes**: 中英文，清晰说明新功能
3. **SHA256**: 始终附带校验和
4. **GitHub Actions**: 优先使用自动化发布

### 维护

1. **依赖更新**: 定期更新 Python 和依赖
2. **安全补丁**: 关注 pywebview/pyobjc 安全公告
3. **用户反馈**: 监控 GitHub Issues
4. **文档更新**: 同步更新所有 .md 文档

---

## 🔗 相关文档

- `PORTABLE_DMG_GUIDE.md` - 架构特定 DMG 指南
- `DMG_BUILD_GUIDE.md` - 标准 DMG 指南（需系统 Python）
- `README.md` - 完整功能说明
- `MAC_INSTALL_TEST.md` - 测试清单

---

**总结**: 通用 DMG 提供最佳的用户体验，单个文件支持所有 Mac，启动器自动架构检测，推荐用于生产分发。
