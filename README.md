# ByteFlow

**macOS 网络流量监控系统** - 实时监控所有应用的网络使用情况，带历史数据图表

[English version below](#english-version)

## 功能特性

- 📊 **实时监控**: 每秒采样一次，实时追踪所有应用的网络流量
- 📈 **历史图表**: 查看任意应用的历史流量趋势
- ⏱️ **多时间精度**: 
  - 最近 24 小时：秒级精度
  - 最近 7 天：分钟级精度
  - 最近 30 天：小时级精度
- 🎨 **美观界面**: 现代化的中文 Web 界面
- 💾 **本地存储**: 所有数据保存在本地 SQLite 数据库
- 🚀 **开箱即用**: 一键启动，无需配置

## 系统要求

- **操作系统**: macOS (Intel 或 Apple Silicon)
- **Python**: 3.8 或更高版本
- **权限**: 需要授予终端访问网络监控的权限

## 快速开始

### 1. 安装

```bash
# 克隆仓库
git clone https://github.com/Freegxx/byteflow.git
cd byteflow

# 安装依赖（start.sh 会自动处理）
```

### 2. 运行

```bash
# 启动 ByteFlow
./start.sh
```

启动后会自动打开两个服务：
- **网络流量采集器**: 后台采集所有应用的网络数据
- **Web 服务器**: 提供 Web 界面访问

### 3. 访问

在浏览器中打开: **http://127.0.0.1:8787**

### 4. 停止

```bash
# 停止 ByteFlow
./stop.sh
```

## 使用说明

### 主界面 - 应用流量概览

主界面显示所有应用的网络使用情况：

- **应用名称**: 点击应用名可查看详细历史图表
- **下载/上传速率**: 当前的实时速率（字节/秒）
- **总下载/上传**: 所选时间段内的总流量
- **时间范围选择**: 可选择查看最近 24 小时、7 天或 30 天的数据

### 历史图表

点击任意应用名称后，会显示该应用的历史流量图表：

- **24小时视图**: 显示秒级精度的流量数据，适合查看短期波动
- **7天视图**: 显示分钟级聚合数据，适合查看每日模式
- **30天视图**: 显示小时级聚合数据，适合查看长期趋势

图表同时显示下载（蓝色）和上传（绿色）两条曲线。

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
├── collector.py      # 网络流量采集器（Python）
├── api.py           # Web API 服务器（FastAPI）
├── web/
│   └── index.html   # 前端界面（Chart.js）
├── byteflow.db      # SQLite 数据库（自动创建）
├── start.sh         # 启动脚本
└── stop.sh          # 停止脚本
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
