# ByteFlow

**macOS 网络流量监控系统** - 实时监控所有应用的网络使用情况，带历史数据图表

[English version below](#english-version)

## 功能特性

### 核心功能
- 📊 **实时监控**: 可配置采样间隔（1秒/2秒/5秒），实时追踪所有应用的网络流量
- 📈 **历史图表**: 查看任意应用的历史流量趋势，支持图表降采样优化
- ⏱️ **多时间精度**: 
  - 最近 24 小时：秒级精度
  - 最近 7 天：分钟级精度
  - 最近 30 天：小时级精度
- 🔄 **定时刷新**: 可选的自动刷新间隔（1秒/3秒/5秒/30秒/1分钟/30分钟），智能增量更新
- 🎨 **美观界面**: 现代化的中文 Web 界面
- 🔍 **搜索过滤**: 快速搜索和筛选应用，支持中文

### 高级功能（v2.0+）
- 🌐 **IP 追踪与过滤**: 
  - 查看每个应用连接的远程 IP 及流量统计
  - 可隐藏回环地址和私有/LAN地址
  - 合并相同 /24 网段显示
- 🧩 **智能进程管理**: 
  - 自动合并 Helper 进程（如 Cursor Helper → Cursor）
  - 支持进程 drill-down 查看各子进程流量占比
- 📍 **流量归属提示**:
  - 区分入站/出站流量
  - 检测 VPN/代理连接
  - 标记回环和私有连接
- ⚠️ **异常标记**: 
  - 记录并显示计数器重置事件
  - 标记首次出现的进程
  - 可视化峰值丢弃事件
- 📱 **菜单栏应用**: macOS 菜单栏显示实时速率和 Top 应用
- 🚀 **一键安装**: 
  - 双击安装器自动配置
  - 可选开机自动启动
  - LaunchAgent 集成
- 💾 **智能存储**: 
  - 本地 SQLite 数据库
  - 自动 30 天数据保留
  - 可配置保留策略

## 系统要求

- **操作系统**: macOS (Intel 或 Apple Silicon)
- **Python**: 3.8 或更高版本
- **权限**: 需要授予终端访问网络监控的权限

## 快速开始

### 方式一: DMG 安装包（最简单，推荐普通用户）

**下载并安装**:
1. 下载 `ByteFlow-v2.0.dmg` （构建方法见下方）
2. 双击打开 DMG 文件
3. 将 `ByteFlow.app` 拖到 `Applications` 文件夹
4. 双击运行 `ByteFlow.app`

**首次运行**:
- 应用会自动安装依赖并配置
- 可选择是否开机自动启动
- 浏览器自动打开 Web 界面

**Gatekeeper 提示**（未签名应用）:
```
右键点击 ByteFlow.app → 打开 → 确认打开
或：系统偏好设置 → 安全性与隐私 → 通用 → "仍要打开"
```

**构建 DMG** （需要 macOS）:
```bash
git clone https://github.com/Freegxx/byteflow.git
cd byteflow
./build_dmg.sh
# 输出: ByteFlow-v2.0.dmg
```

详细说明见 `DMG_BUILD_GUIDE.md`。

### 方式二: Install.command 脚本（推荐开发者）

```bash
# 1. 克隆仓库
git clone https://github.com/Freegxx/byteflow.git
cd byteflow

# 2. 运行安装器
chmod +x Install.command
./Install.command

# 按提示完成安装，可选择开机自动启动
```

安装器会：
- ✅ 将 ByteFlow 安装到 `~/Applications/ByteFlow`
- ✅ 创建 Python 虚拟环境
- ✅ 自动安装依赖
- ✅ 配置 LaunchAgent（可选开机启动）

### 方式三: 手动运行

```bash
# 1. 克隆仓库
git clone https://github.com/Freegxx/byteflow.git
cd byteflow

# 2. 安装依赖
pip3 install -r requirements.txt

# 3. 启动 ByteFlow
./start.sh

# 4. 访问 Web UI
open http://127.0.0.1:8787

# 5. 停止服务
./stop.sh
```

### 首次运行配置

#### 1. 终端权限（必需）
**系统偏好设置 → 安全性与隐私 → 隐私 → 完全磁盘访问**

添加您使用的终端应用（Terminal.app 或 iTerm.app）

#### 2. Gatekeeper 处理
如遇"无法验证开发者"提示：
- 右键点击 → 打开 → 确认

或使用命令：
```bash
xattr -d com.apple.quarantine ByteFlow.command
```

### 启动菜单栏应用（可选）

```bash
# 显示实时速率和 Top 应用
python3 menubar.py
```

## 使用说明

### 主界面 - 应用流量概览

主界面显示所有应用的网络使用情况：

- **应用名称**: 点击应用名可查看详细历史图表
- **下载/上传速率**: 当前的实时速率（字节/秒）
- **总下载/上传**: 所选时间段内的总流量
- **时间范围选择**: 可选择查看最近 24 小时、7 天或 30 天的数据
- **搜索过滤**: 在搜索框中输入应用名称快速筛选
- **快速跳转**: 使用下拉选择器快速打开应用详情
- **定时刷新**: 选择自动刷新间隔（关闭/1秒/3秒/5秒/30秒/1分钟/30分钟）

### 历史图表（模态弹窗）

点击任意应用名称后，会在模态弹窗中显示该应用的详细信息：

**使用量汇总卡片**（顶部）：
- 24小时使用量
- 7天使用量
- 30天使用量

**历史流量图表**：
- **24小时视图**: 显示秒级精度的流量数据，适合查看短期波动
- **7天视图**: 显示分钟级聚合数据，适合查看每日模式
- **30天视图**: 显示小时级聚合数据，适合查看长期趋势
- 图表同时显示下载（蓝色）和上载（绿色）两条曲线

**智能刷新**：
- 如果启用了定时刷新，模态框会自动更新（不关闭）
- 使用 ESC 键或点击背景关闭模态框

### 远程 IP 列表

在应用详情页面的图表下方，显示该应用连接的所有远程 IP 地址：

- **IP 地址**: 应用连接的远程服务器 IP
- **下载/上传**: 与该 IP 的流量统计
- **总计**: 该 IP 的总流量（人类可读格式 + MB）
- **自动刷新**: 切换时间范围时自动更新

### 应用名称智能合并

ByteFlow 会自动合并辅助进程到主应用，避免重复显示：

**合并规则**：
- 包含 " Helper" 的进程会合并到主应用
- 示例：
  - `Cursor` + `Cursor Helper` + `Cursor Helper (GPU)` → 统一显示为 `Cursor`
  - `Google Chrome` + `Google Chrome Helper (Renderer)` → 统一显示为 `Google Chrome`
  - `Microsoft Edge Helper (GPU)` → 合并到 `Microsoft Edge`
  
**保持独立**：
- 中文应用名称保持原样（如 `企业微信`、`微信`）
- 不包含 Helper 的应用保持独立显示

这样可以：
- ✅ 避免同一应用的多个进程占据列表
- ✅ 准确统计应用的总流量（包含所有辅助进程）
- ✅ 简化界面，更易于理解

## 技术架构

### 系统组件

```
ByteFlow
├── ByteFlow.app/           # macOS 应用包（双击安装）
│   └── Contents/
│       ├── MacOS/
│       │   └── ByteFlow    # 启动器（处理安装/启动）
│       ├── Resources/      # 应用代码（下方文件）
│       └── Info.plist      # 应用信息
├── collector.py            # 网络流量采集器（Python）
├── api.py                  # Web API 服务器（FastAPI）
├── menubar.py              # 菜单栏应用（可选）
├── config.py               # 配置管理
├── utils.py                # 工具函数
├── web/
│   └── index.html          # 前端界面（Chart.js）
├── byteflow.db             # SQLite 数据库（自动创建）
├── build_dmg.sh            # DMG 构建脚本
├── Install.command         # 备选安装器
├── start.sh                # 启动脚本
└── stop.sh                 # 停止脚本
```

### 数据采集原理

1. **采集工具**: 使用 macOS 自带的 `nettop` 命令
2. **采样频率**: 每秒采样一次
3. **数据处理**: 
   - 按进程名聚合流量
   - 计算相邻采样点的差值得到实时速率
   - 保存到 SQLite 数据库

### 数据存储策略

ByteFlow 使用三层存储结构，自动管理历史数据：

| 数据表 | 精度 | 保留时长 | 用途 |
|--------|------|----------|------|
| `traffic_raw` | 秒级 | 24 小时 | 实时数据和短期查询 |
| `traffic_minute` | 分钟级 | 7 天 | 中期趋势分析 |
| `traffic_hour` | 小时级 | 30 天 | 长期趋势分析 |

**自动数据汇总**:
- 每 60 秒将秒级数据聚合为分钟级数据
- 每小时将分钟级数据聚合为小时级数据
- 每 10 分钟清理过期数据

### API 接口

- `GET /`: Web 界面首页
- `GET /api/overview?period={24h|7d|30d}`: 获取应用流量概览
- `GET /api/history/{app_name}?range={24h|7d|30d}`: 获取应用历史数据
- `GET /api/stats`: 获取系统统计信息

## macOS 权限说明

首次运行时，macOS 可能会要求以下权限：

1. **终端访问权限**: 系统偏好设置 > 安全性与隐私 > 隐私 > 完全磁盘访问
2. **网络监控权限**: 运行 `nettop` 命令需要管理员权限或授权

如果遇到权限问题：

```bash
# 使用 sudo 运行采集器（需要管理员密码）
sudo python3 collector.py
```

## 故障排除

### 问题：采集器无法启动

**原因**: `nettop` 命令不可用或权限不足

**解决方案**:
1. 确认系统为 macOS
2. 检查终端权限设置
3. 尝试使用 `sudo` 运行

### 问题：Web 界面显示"加载数据失败"

**原因**: 采集器未运行或数据库不存在

**解决方案**:
1. 确认采集器正在运行（检查 `.pids/collector.pid`）
2. 查看 `byteflow.db` 文件是否存在
3. 重新启动 `./start.sh`

### 问题：数据不更新

**原因**: 采集器进程异常退出

**解决方案**:
```bash
# 停止所有服务
./stop.sh

# 重新启动
./start.sh
```

## 数据文件位置

- **数据库文件**: `./byteflow.db`
- **进程 PID 文件**: `./.pids/`

如需重置数据，删除 `byteflow.db` 文件即可。

## 开发说明

### 修改采样频率

编辑 `collector.py`，修改 `SAMPLE_INTERVAL` 常量：

```python
SAMPLE_INTERVAL = 1  # 秒
```

### 修改数据保留时长

编辑 `collector.py` 中的 `cleanup_old_data()` 方法。

### 自定义 Web 端口

编辑 `api.py`，修改 `uvicorn.run()` 中的 `port` 参数：

```python
uvicorn.run(app, host="127.0.0.1", port=8787)
```

## 注意事项

- ⚠️ **隐私**: ByteFlow 所有数据保存在本地，不会上传到任何服务器
- ⚠️ **性能**: 采集器使用极少的系统资源（<1% CPU）
- ⚠️ **数据量**: 数据库大小取决于应用数量和运行时长，通常不会超过 100MB
- ⚠️ **系统限制**: 本工具不需要系统扩展或 App Store 签名，但 `nettop` 可能需要管理员权限

## 许可证

MIT License

---

## English Version

**ByteFlow** - A macOS network traffic monitoring application with historical charts

### Quick Start

```bash
# Clone and run
git clone https://github.com/Freegxx/byteflow.git
cd byteflow
./start.sh

# Access web interface
open http://127.0.0.1:8787
```

### Features

- Real-time per-application network traffic monitoring
- Historical charts with multiple time resolutions (24h/7d/30d)
- Clean web interface (Chinese UI)
- Local SQLite storage
- No system extensions required

### Requirements

- macOS (Intel or Apple Silicon)
- Python 3.8+
- Terminal access permissions for `nettop`

### Architecture

- **Collector**: Python script using `nettop` to sample network traffic every second
- **API Server**: FastAPI backend serving traffic data
- **Web UI**: Single-page application with Chart.js for visualization
- **Database**: SQLite with automatic data rollup and retention

### Technical Details

**Data Collection**:
- Uses macOS built-in `nettop` command
- 1-second sampling interval
- Aggregates traffic by process name

**Data Storage**:
- Raw data (1s precision): 24 hours
- Minute data: 7 days
- Hourly data: 30 days

**API Endpoints**:
- `GET /api/overview?period={24h|7d|30d}` - Overview of all apps
- `GET /api/history/{app_name}?range={24h|7d|30d}` - App history
- `GET /api/stats` - System statistics

### Stopping

```bash
./stop.sh
```

### Notes

- All data stored locally (no cloud sync)
- Minimal resource usage (<1% CPU)
- May require admin permissions for `nettop`
- No Network Extension or App Store signing required

---

**项目地址**: https://github.com/Freegxx/byteflow

**问题反馈**: https://github.com/Freegxx/byteflow/issues
