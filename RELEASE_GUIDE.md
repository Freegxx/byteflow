# ByteFlow Release Guide

## 如何发布新版本

### 方法一：通过 Git Tag 触发（推荐）

```bash
# 1. 确保本地代码是最新的
git pull origin main

# 2. 创建版本标签
git tag v1.2.1

# 3. 推送标签到 GitHub
git push origin v1.2.1
```

GitHub Actions 会自动：
1. 在 macOS runner 上构建 Universal DMG
2. 创建 GitHub Release
3. 上传 `ByteFlow-universal.dmg` 和 `ByteFlow-universal.dmg.sha256`

### 方法二：通过 GitHub Web UI 手动触发

1. 访问 [GitHub Actions](https://github.com/Freegxx/byteflow/actions/workflows/release.yml)
2. 点击 **Run workflow**
3. 选择分支（默认 main）
4. 输入版本号（如 `v1.2.1`）
5. 点击 **Run workflow** 按钮

### 方法三：通过 GitHub CLI 手动触发

```bash
# 需要先安装 gh CLI 并登录
gh workflow run release.yml -f version=v1.2.1
```

---

## 版本号规范

遵循语义化版本控制（Semantic Versioning）：

- **主版本号（Major）**: 不兼容的 API 修改
- **次版本号（Minor）**: 向下兼容的功能性新增
- **修订号（Patch）**: 向下兼容的问题修正

示例：
- `v1.0.0` - 初始发布
- `v1.1.0` - 添加新功能（如 IP 追踪）
- `v1.2.0` - 添加原生桌面窗口
- `v1.2.1` - 修复关键 bug（collector 准确性、离线图表、DMG 优化）

---

## 发布前检查清单

- [ ] 所有关键 bug 已修复
- [ ] 本地运行 `./build_universal_dmg.command` 成功
- [ ] DMG 在本地 Mac 上测试通过（Apple Silicon 或 Intel）
- [ ] README.md 更新（版本号、新特性说明）
- [ ] CHANGELOG 或 release notes 准备完毕
- [ ] 所有测试通过
- [ ] 代码已推送到 main 分支

---

## 发布后验证

1. 访问 [Releases 页面](https://github.com/Freegxx/byteflow/releases)
2. 确认新版本已发布
3. 下载 `ByteFlow-universal.dmg`
4. 验证 DMG 大小（应为 ~40-60MB）
5. 在 Mac 上安装并测试
6. 验证 SHA256 校验和

---

## 当前版本

**v1.2.1** (2026-09-18)

### 关键修复
- 修复 collector 将连接行错误识别为应用的问题
- 修复模态窗口图表无法显示的问题（离线 Chart.js）
- 添加应用图标（.icns）
- DMG 大幅优化：~75MB+ → ~40-60MB

---

## 构建详情

- **构建环境**: GitHub Actions `macos-latest`
- **Python**: 3.12.14 (python-build-standalone install_only_stripped)
- **架构**: arm64 + x86_64 (Universal)
- **构建时间**: ~10-15 分钟（首次），~5-8 分钟（缓存后）
- **输出**: `ByteFlow-universal.dmg` (~40-60MB)

---

## 常见问题

### Q: 构建失败怎么办？
A: 检查 GitHub Actions 日志，常见原因：
- Python 下载失败（网络问题）
- 依赖安装失败（pyobjc 版本不兼容）
- DMG 创建失败（磁盘空间不足）

### Q: 如何删除已发布的版本？
A: 
1. 删除 GitHub Release（Web UI）
2. 删除 Git Tag: `git push --delete origin v1.2.1`

### Q: 如何更新已发布版本的 Release Notes？
A: 
1. 访问 Releases 页面
2. 点击版本旁的 "Edit"
3. 修改 Release Notes
4. 保存

---

## 技术细节

### GitHub Actions Workflow

文件位置: `.github/workflows/release.yml`

触发条件:
- 推送 `v*` 标签
- 手动触发（workflow_dispatch）

关键步骤:
1. Checkout 代码
2. 设置 Python 3.11
3. 运行 `./build_universal_dmg.command`
4. 计算 SHA256
5. 创建 GitHub Release
6. 上传 DMG 和 SHA256 文件

### 构建脚本

文件位置: `packaging/build_universal_dmg.command`

功能:
1. 下载 python-build-standalone 双架构（install_only_stripped）
2. 为每个架构安装依赖（pywebview, fastapi, uvicorn, aiosqlite, rumps, pyobjc）
3. 清理缓存和测试文件（`__pycache__`, `tests`, pip/setuptools/wheel）
4. 创建启动器（自动检测架构）
5. 生成应用图标（.icns）
6. 打包成 DMG（UDZO 压缩）

---

## 联系方式

如有问题，请在 GitHub Issues 中提出。
