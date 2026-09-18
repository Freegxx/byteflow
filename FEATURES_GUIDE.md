# ByteFlow 新功能指南

本文档说明 ByteFlow 的8个新增主要功能及使用方法。

## 1. IP 过滤设置

### 功能说明
- 隐藏回环地址 (127.0.0.0/8, ::1)
- 隐藏私有/LAN地址 (10/8, 172.16/12, 192.168/16, link-local等)
- 合并相同 IPv4 /24 网段

### 使用方法
1. 打开设置界面（Web UI 右上角）
2. 勾选相应选项
3. 设置自动保存到 `byteflow_config.json`

### API端点
- `GET /api/config` - 获取当前配置
- `POST /api/config` - 更新配置

### 实现文件
- `config.py` - 配置管理
- `utils.py` - IP过滤工具函数
- `api.py` - 配置API端点

## 2. Mac App 打包 + 开机启动

### 安装方式

#### 方式1: 使用安装脚本（推荐）
```bash
# 双击运行或终端执行
./Install.command
```

安装脚本会：
1. 将 ByteFlow 安装到 `~/Applications/ByteFlow`
2. 安装 Python 依赖
3. 询问是否设置开机启动
4. 创建 LaunchAgent (com.byteflow.agent.plist)
5. 创建桌面启动快捷方式

#### 方式2: 手动安装
```bash
# 复制到应用目录
cp -r byteflow ~/Applications/ByteFlow

# 进入目录
cd ~/Applications/ByteFlow

# 安装依赖
pip3 install -r requirements.txt

# 启动
./start.sh
```

### 开机启动配置

LaunchAgent 配置文件位置：
```
~/Library/LaunchAgents/com.byteflow.agent.plist
```

管理命令：
```bash
# 加载（启用开机启动）
launchctl load ~/Library/LaunchAgents/com.byteflow.agent.plist

# 卸载（禁用开机启动）
launchctl unload ~/Library/LaunchAgents/com.byteflow.agent.plist

# 立即启动
launchctl start com.byteflow.agent

# 停止
launchctl stop com.byteflow.agent
```

### Gatekeeper 处理

首次运行可能遇到"无法验证开发者"提示：

**方法1**: 右键 > 打开
1. 右键点击 `ByteFlow.command`
2. 选择"打开"
3. 点击"打开"确认

**方法2**: 系统设置
1. 系统偏好设置 > 安全性与隐私 > 通用
2. 看到被阻止的提示后，点击"仍要打开"

**方法3**: 命令行（开发者）
```bash
xattr -d com.apple.quarantine ByteFlow.command
```

## 3. 30天数据保留

### 功能说明
- 每日自动清理超过30天的数据
- 按表类型清理（raw/minute/hour）
- 清理日志记录到控制台

### 配置
```json
{
  "retention_days": 30
}
```

### 实现
- collector.py 中的 `cleanup_old_data()` 方法
- 每次采集循环检查是否需要清理（每小时一次）

## 4. 性能优化

### 4.1 图表降采样

24小时数据可能有86400个点，降采样到~1000点：

**API侧降采样**:
```python
from utils import downsample_data, aggregate_by_bucket

# 获取数据后
data_points = downsample_data(data_points, max_points=1000)
```

**前端侧降采样**: 
- 在 `loadChartData()` 中根据数据点数量决定是否降采样

### 4.2 可配置采样间隔

支持 1秒/2秒/5秒 采样间隔：

**配置文件** (`byteflow_config.json`):
```json
{
  "sample_interval": 1
}
```

**通过API更新**:
```bash
curl -X POST http://127.0.0.1:8787/api/config \
  -H "Content-Type: application/json" \
  -d '{"sample_interval": 2}'
```

**注意**: 修改采样间隔后需重启collector生效。

## 5. 进程Drill-Down

### 功能说明
- 查看合并应用（如Cursor）的所有进程详情
- 显示每个Helper进程的流量占比
- 按时间范围查询

### 使用方法
1. 打开应用详情（点击应用名）
2. 点击"查看进程详情"按钮
3. 显示所有贡献进程及其流量

### API端点
```
GET /api/process_details/{app_name}?range=24h
```

返回：
```json
{
  "app_name": "Cursor",
  "processes": [
    {
      "process_name": "Cursor.1234",
      "bytes_in": 5242880,
      "bytes_out": 1048576,
      "total": 6291456
    },
    {
      "process_name": "Cursor Helper.5678",
      "bytes_in": 2097152,
      "bytes_out": 524288,
      "total": 2621440
    }
  ]
}
```

### 数据库表
```sql
CREATE TABLE process_details (
    id INTEGER PRIMARY KEY,
    app_name TEXT NOT NULL,
    process_name TEXT NOT NULL,
    pid INTEGER,
    timestamp INTEGER NOT NULL,
    bytes_in INTEGER NOT NULL,
    bytes_out INTEGER NOT NULL
);
```

## 6. 流量归属提示

### 功能说明
- 区分入站/出站流量
- 标记回环连接
- 检测VPN/代理连接

### 检测逻辑

**VPN检测** (`utils.py`):
```python
def detect_vpn_interface(connection_str):
    # 检测 utun, ppp, ipsec, tun, tap 等接口
    vpn_indicators = ['utun', 'ppp', 'ipsec', 'tun', 'tap']
    return any(indicator in connection_str.lower() for indicator in vpn_indicators)
```

**代理端口检测**:
```python
def detect_proxy_port(port):
    # 常见代理端口
    proxy_ports = [1080, 3128, 8080, 8118, 8888, 9050, 9150]
    return port in proxy_ports
```

**入站/出站判断**:
```python
def is_inbound(connection_str):
    # 本地端口是常见服务端口 → 入站
    service_ports = [80, 443, 22, 21, 25, 110, 143, 993, 995]
    # 解析并判断
```

### UI提示

在IP列表中显示图标：
- 🔄 回环
- 🏠 私有/LAN
- 🔒 VPN/代理
- ⬇️ 入站
- ⬆️ 出站

## 7. 异常/峰值标记

### 功能说明
- 记录计数器重置事件
- 记录首次出现的进程
- 记录被丢弃的异常峰值

### 标记类型

1. **counter_reset**: 计数器重置/进程重启
2. **first_seen**: 新进程首次出现
3. **spike_discarded**: 异常峰值被丢弃

### 数据库表
```sql
CREATE TABLE spike_markers (
    id INTEGER PRIMARY KEY,
    app_name TEXT NOT NULL,
    process_name TEXT,
    timestamp INTEGER NOT NULL,
    reason TEXT NOT NULL,
    delta_in INTEGER,
    delta_out INTEGER
);
```

### API端点
```
GET /api/spike_markers?range=24h
```

返回：
```json
{
  "markers": [
    {
      "app_name": "Chrome",
      "process_name": "Chrome Helper.1234",
      "timestamp": 1726637400,
      "reason": "spike_discarded",
      "delta_in": 524288000,
      "delta_out": 104857600
    }
  ]
}
```

### 图表显示

在Chart.js中添加annotation插件显示标记：
```javascript
{
  type: 'point',
  xValue: timestamp,
  yValue: 0,
  backgroundColor: 'rgba(255, 99, 132, 0.25)',
  radius: 10
}
```

## 8. 菜单栏应用

### 功能说明
- 显示实时总速率
- 显示Top 5应用及其速率
- 点击打开完整Web UI

### 使用方法

**启动菜单栏应用**:
```bash
python3 menubar.py
```

或在后台启动：
```bash
nohup python3 menubar.py > /dev/null 2>&1 &
```

### 菜单结构
```
📊 25.3 MB/s              # 图标+总速率
─────────────────
打开主界面
─────────────────
总速率: 25.3 MB/s
─────────────────
Top 应用
  Chrome: 15.2 MB/s
  Cursor: 8.5 MB/s
  微信: 1.4 MB/s
  Safari: 0.2 MB/s
─────────────────
退出
```

### 自动启动

将以下内容添加到 LaunchAgent plist 的 ProgramArguments：
```xml
<key>ProgramArguments</key>
<array>
    <string>/usr/bin/python3</string>
    <string>/path/to/menubar.py</string>
</array>
```

### 依赖
```bash
pip install rumps
```

**注意**: rumps 仅在 macOS 上工作，Linux上无法测试。

## 配置文件示例

`byteflow_config.json`:
```json
{
  "hide_loopback": false,
  "hide_private": false,
  "merge_ipv4_24": false,
  "sample_interval": 1,
  "retention_days": 30,
  "chart_max_points": 1000
}
```

## 故障排除

### 1. 菜单栏应用无法启动
```bash
# 检查rumps是否安装
pip list | grep rumps

# 重新安装
pip install --upgrade rumps
```

### 2. LaunchAgent未自动启动
```bash
# 检查plist语法
plutil -lint ~/Library/LaunchAgents/com.byteflow.agent.plist

# 查看日志
tail -f ~/Applications/ByteFlow/logs/stderr.log

# 手动加载
launchctl load -w ~/Library/LaunchAgents/com.byteflow.agent.plist
```

### 3. 权限问题
```bash
# 检查终端权限
# 系统偏好设置 > 安全性与隐私 > 完全磁盘访问
# 添加 Terminal.app 或 iTerm.app
```

### 4. nettop无法运行
```bash
# 测试nettop
nettop -L 1 -J bytes_in,bytes_out -x

# 如果失败，检查是否在macOS上
uname -a
```

## 开发者信息

### 项目结构
```
byteflow/
├── collector.py          # 数据采集器（增强）
├── api.py               # API服务器（增强）
├── config.py            # 配置管理（新）
├── utils.py             # 工具函数（新）
├── menubar.py           # 菜单栏应用（新）
├── Install.command      # 安装脚本（新）
├── start.sh            # 启动脚本
├── stop.sh             # 停止脚本
├── requirements.txt    # Python依赖（更新）
├── byteflow_config.json # 配置文件（运行时生成）
├── web/                # 前端文件
│   └── index.html      # Web UI（增强）
└── logs/               # 日志目录
```

### 测试清单

- [ ] IP过滤功能测试
- [ ] 安装脚本测试（Mac）
- [ ] 开机启动测试（Mac）
- [ ] 30天清理测试
- [ ] 图表降采样测试
- [ ] 采样间隔修改测试
- [ ] 进程drill-down测试
- [ ] VPN/代理检测测试
- [ ] 异常标记显示测试
- [ ] 菜单栏应用测试（Mac）

### 已知限制

1. 菜单栏应用仅支持macOS（rumps限制）
2. LaunchAgent需要macOS launchd
3. Gatekeeper需要macOS安全机制
4. nettop命令仅在macOS可用

### 后续改进

1. 添加Web UI设置页面
2. 图表上显示异常标记annotation
3. 进程drill-down UI组件
4. IP归属的可视化图标
5. 更详细的VPN检测
6. 性能分析工具

---

**版本**: v2.0.0-beta  
**更新日期**: 2026-09-18  
**作者**: ByteFlow Team
