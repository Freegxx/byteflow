# ByteFlow 架构设计文档

## 系统概览

ByteFlow 是一个 macOS 本地网络流量监控系统，采用前后端分离架构，包含数据采集、存储、API 和 Web 可视化四个核心模块。

## 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                         ByteFlow                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────┐        ┌──────────────┐                │
│  │   collector   │───────>│   SQLite DB  │                │
│  │   (Python)    │        │  byteflow.db │                │
│  └───────────────┘        └──────────────┘                │
│         │                        │                          │
│         │ nettop                 │ queries                  │
│         ↓                        ↓                          │
│  ┌───────────────┐        ┌──────────────┐                │
│  │  macOS System │        │  FastAPI     │                │
│  │  (nettop)     │        │  api.py      │                │
│  └───────────────┘        └──────────────┘                │
│                                  │                          │
│                                  │ HTTP/REST                │
│                                  ↓                          │
│                           ┌──────────────┐                 │
│                           │  Web UI      │                 │
│                           │  index.html  │                 │
│                           └──────────────┘                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 模块详解

### 1. 数据采集器 (collector.py)

**职责**：
- 调用 macOS `nettop` 命令采集网络流量
- 解析 nettop 输出，按进程聚合数据
- 计算流量速率（相邻采样点差值）
- 写入 SQLite 数据库
- 定期执行数据汇总和清理

**关键类**：
```python
class NetworkCollector:
    - init_database()           # 初始化数据库表
    - collect_nettop_data()     # 调用 nettop 采集
    - parse_nettop_output()     # 解析输出
    - save_traffic_data()       # 保存到数据库
    - rollup_data()             # 数据汇总（秒→分钟→小时）
    - cleanup_old_data()        # 清理过期数据
    - run()                     # 主循环
```

**采样逻辑**：
1. 每秒执行 `nettop -P -L 1 -J bytes_in,bytes_out -x`
2. 解析输出，提取进程名和字节数
3. 计算与上次采样的差值得到速率
4. 保存到 `traffic_raw` 表

**汇总逻辑**：
- 每 60 秒：聚合秒级数据到分钟表
- 每小时：聚合分钟级数据到小时表
- 使用 `GROUP BY app_name` 和 `SUM()` 聚合

### 2. 数据库设计

**表结构**：

```sql
-- 原始数据表（秒级）
CREATE TABLE traffic_raw (
    id INTEGER PRIMARY KEY,
    app_name TEXT NOT NULL,
    bundle_id TEXT,
    timestamp INTEGER NOT NULL,
    bytes_in INTEGER NOT NULL,
    bytes_out INTEGER NOT NULL,
    rate_in REAL NOT NULL,
    rate_out REAL NOT NULL
);

-- 分钟聚合表
CREATE TABLE traffic_minute (
    id INTEGER PRIMARY KEY,
    app_name TEXT NOT NULL,
    bundle_id TEXT,
    timestamp INTEGER NOT NULL,
    bytes_in INTEGER NOT NULL,
    bytes_out INTEGER NOT NULL,
    UNIQUE(app_name, timestamp)
);

-- 小时聚合表
CREATE TABLE traffic_hour (
    id INTEGER PRIMARY KEY,
    app_name TEXT NOT NULL,
    bundle_id TEXT,
    timestamp INTEGER NOT NULL,
    bytes_in INTEGER NOT NULL,
    bytes_out INTEGER NOT NULL,
    UNIQUE(app_name, timestamp)
);
```

**索引**：
- 每个表在 `timestamp` 和 `app_name` 上建立索引
- 加速时间范围查询和应用过滤

**数据生命周期**：
```
秒级数据 (traffic_raw)
    保留 24 小时
    ↓ 每分钟汇总
分钟级数据 (traffic_minute)
    保留 7 天
    ↓ 每小时汇总
小时级数据 (traffic_hour)
    保留 30 天
    ↓ 定期清理
删除
```

### 3. API 服务器 (api.py)

**技术栈**：FastAPI + Uvicorn

**端点**：

| 端点 | 方法 | 参数 | 功能 |
|------|------|------|------|
| `/` | GET | - | 返回 Web 界面 HTML |
| `/api/overview` | GET | `period` (24h/7d/30d) | 获取应用流量概览 |
| `/api/history/{app_name}` | GET | `range` (24h/7d/30d) | 获取应用历史数据 |
| `/api/stats` | GET | - | 获取系统统计信息 |

**查询逻辑**：

```python
# 概览查询 - 自动选择数据源
if period == "24h":
    table = "traffic_raw"
    since = now - 24 * 3600
elif period == "7d":
    table = "traffic_minute"
    since = now - 7 * 24 * 3600
else:  # 30d
    table = "traffic_hour"
    since = now - 30 * 24 * 3600

# 聚合查询
SELECT app_name, SUM(bytes_in), SUM(bytes_out)
FROM {table}
WHERE timestamp >= {since}
GROUP BY app_name
ORDER BY total DESC
```

### 4. Web 前端 (web/index.html)

**技术栈**：
- 原生 HTML/CSS/JavaScript（无框架）
- Chart.js 4.4.0（图表库）
- Fetch API（数据请求）

**页面结构**：

```html
├── Header（标题和副标题）
├── Stats Cards（统计卡片）
│   ├── 监控应用数
│   ├── 总下载流量
│   └── 总上传流量
├── Controls（控制栏）
│   ├── 时间范围选择器
│   └── 刷新按钮
├── Overview Section（概览页面）
│   └── 应用流量表格
└── Chart Section（图表页面）
    ├── 返回按钮 + 应用名称
    ├── 时间范围切换器
    └── Chart.js 双线图
```

**数据流**：

```
1. 页面加载
   ↓
2. loadOverview('24h')
   ↓
3. fetch('/api/overview?period=24h')
   ↓
4. 渲染表格 + 更新统计卡片
   ↓
5. 用户点击应用名
   ↓
6. showChart(appName)
   ↓
7. loadChartData(appName, '24h')
   ↓
8. fetch('/api/history/{app}?range=24h')
   ↓
9. Chart.js 渲染双线图
```

**自动刷新**：
- 每 30 秒自动刷新概览数据
- 仅在概览页面刷新，图表页面不自动刷新

### 5. 启动脚本 (start.sh)

**功能**：
1. 检查 macOS 系统
2. 检查 Python 3 版本
3. 创建/激活虚拟环境
4. 安装依赖包
5. 后台启动采集器
6. 后台启动 API 服务器
7. 保存进程 PID

**进程管理**：
```bash
# 启动采集器
python3 collector.py &
COLLECTOR_PID=$!
echo $COLLECTOR_PID > .pids/collector.pid

# 启动 API 服务器
python3 api.py &
API_PID=$!
echo $API_PID > .pids/api.pid
```

### 6. 停止脚本 (stop.sh)

**功能**：
1. 读取 PID 文件
2. 检查进程是否存在
3. 发送 SIGTERM 信号终止进程
4. 清理 PID 文件

## 数据流图

```
┌──────────┐
│  nettop  │ 每秒采样
└────┬─────┘
     │
     ↓
┌────────────────┐
│  collector.py  │ 解析 + 计算速率
└────┬───────────┘
     │
     ↓
┌────────────────┐
│   SQLite DB    │
│  - traffic_raw │ (秒级，24h)
│  - traffic_min │ (分钟级，7d)
│  - traffic_hour│ (小时级，30d)
└────┬───────────┘
     │
     ↓
┌────────────────┐
│    api.py      │ RESTful API
└────┬───────────┘
     │
     ↓
┌────────────────┐
│  Web Browser   │
│  - 概览表格     │
│  - 历史图表     │
└────────────────┘
```

## 性能优化

### 1. 数据库优化
- 使用索引加速查询
- 分层存储减少数据量
- 自动清理过期数据

### 2. 采集器优化
- 1 秒采样间隔（可配置）
- 异步信号处理
- 增量计算速率（避免重复计算）

### 3. API 优化
- 按时间范围自动选择最优数据表
- 聚合查询减少数据传输
- 连接池复用数据库连接

### 4. 前端优化
- 节流刷新（30 秒间隔）
- 按需加载图表数据
- 单页应用减少页面跳转

## 错误处理

### 1. 系统检查
- 检查操作系统是否为 macOS
- 检查 Python 版本
- 检查 nettop 命令可用性

### 2. 运行时错误
- nettop 超时重试
- 数据库连接失败处理
- API 查询错误返回友好消息
- 前端显示错误提示

### 3. 优雅退出
- 捕获 SIGINT/SIGTERM 信号
- 保存未提交的数据
- 关闭数据库连接
- 清理临时文件

## 扩展性

### 添加新的数据源
修改 `collector.py` 中的 `collect_nettop_data()` 方法，支持其他数据采集工具。

### 添加新的聚合维度
在数据库中添加新表，修改 `rollup_data()` 方法支持新的聚合逻辑。

### 添加新的 API 端点
在 `api.py` 中添加新的路由函数。

### 自定义前端
修改 `web/index.html`，或创建新的前端项目（React/Vue）连接现有 API。

## 安全考虑

1. **本地运行**：所有数据保存在本地，不上传到服务器
2. **最小权限**：仅需要读取网络统计信息的权限
3. **API 限制**：API 仅监听 127.0.0.1，不暴露到外网
4. **数据隐私**：不记录具体的网络请求内容，仅统计字节数

## 测试策略

### 单元测试（未实现，可扩展）
- 测试 nettop 输出解析
- 测试速率计算逻辑
- 测试数据汇总算法

### 集成测试（未实现，可扩展）
- 测试采集器到数据库的完整流程
- 测试 API 端点返回数据格式
- 测试前端数据渲染

### 手动测试
- 在 macOS 上运行 `./start.sh`
- 访问 Web 界面验证功能
- 等待数据积累后测试历史图表

## 部署清单

- [x] 采集器脚本（collector.py）
- [x] API 服务器（api.py）
- [x] Web 前端（web/index.html）
- [x] 启动脚本（start.sh）
- [x] 停止脚本（stop.sh）
- [x] 依赖文件（requirements.txt）
- [x] 说明文档（README.md）
- [x] 架构文档（ARCHITECTURE.md）
- [x] Git 忽略文件（.gitignore）

## 总结

ByteFlow 采用模块化设计，各组件职责清晰，易于理解和维护。系统使用成熟的技术栈（Python、FastAPI、SQLite、Chart.js），保证了稳定性和性能。通过分层存储和自动汇总，在提供多精度历史查询的同时，有效控制了数据库大小。
