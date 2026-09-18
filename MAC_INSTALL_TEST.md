# ByteFlow macOS 安装和测试清单

## 前置要求

- macOS 10.14+ (Intel 或 Apple Silicon)
- Python 3.8+
- 终端权限（完全磁盘访问）

## 快速安装

### 方式 A: 便携式 DMG（推荐生产分发，无需系统 Python）

1. **构建便携式 DMG**（需要在 macOS 上 + 联网一次）:
   ```bash
   git clone https://github.com/Freegxx/byteflow.git
   cd byteflow
   git checkout cursor/byteflow-macos-network-monitor-9efb
   ./build_portable_dmg.sh
   
   # 输出（根据当前 Mac 架构）:
   # ByteFlow-v2.0-arm64.dmg (Apple Silicon)
   # ByteFlow-v2.0-x86_64.dmg (Intel)
   ```

2. **安装**（可在无 Python 的 Mac 上离线安装）:
   - 双击 `ByteFlow-v2.0-arm64.dmg` 或 `ByteFlow-v2.0-x86_64.dmg`
   - 将 `ByteFlow.app` 拖到 `Applications` 文件夹
   - 右键点击 `ByteFlow.app` → 打开（绕过 Gatekeeper）

3. **首次运行**:
   - 应用显示欢迎对话框
   - 自动配置数据目录（`~/Library/Application Support/ByteFlow`）
   - 询问是否开机启动
   - 询问是否启动菜单栏应用
   - 浏览器自动打开 Web 界面

4. **特点**:
   - ✅ 内嵌 Python 3.11.9 运行时
   - ✅ 所有依赖已预装（fastapi, uvicorn, rumps, etc.）
   - ✅ 无需系统 Python 或 pip
   - ✅ 无需联网安装依赖
   - ✅ DMG 大小 ~150-200MB

5. **Gatekeeper 处理**（未签名应用）:
   - 右键点击 `ByteFlow.app` → 打开 → 确认打开
   - 或：系统偏好设置 → 安全性与隐私 → 通用 → "仍要打开"

详细文档: `PORTABLE_DMG_GUIDE.md`

---

### 方式 B: 标准 DMG（需要系统 Python 3.8+）

1. **构建标准 DMG**（需要在 macOS 上）:
   ```bash
   git clone https://github.com/Freegxx/byteflow.git
   cd byteflow
   git checkout cursor/byteflow-macos-network-monitor-9efb
   ./build_dmg.sh
   ```

2. **安装**:
   - 双击 `ByteFlow-v2.0.dmg`
   - 将 `ByteFlow.app` 拖到 `Applications` 文件夹
   - 双击 `ByteFlow.app` 运行

3. **首次运行**:
   - 应用会显示欢迎对话框
   - 自动安装依赖（需联网，进度通知）
   - 询问是否开机启动
   - 询问是否启动菜单栏应用
   - 浏览器自动打开 Web 界面

4. **Gatekeeper 处理**（未签名应用）:
   - 右键点击 `ByteFlow.app` → 打开 → 确认打开
   - 或：系统偏好设置 → 安全性与隐私 → 通用 → "仍要打开"

---

### 方式 C: Install.command 脚本（推荐开发者）

```bash
# 1. 克隆或下载代码
git clone https://github.com/Freegxx/byteflow.git
cd byteflow
git checkout cursor/byteflow-macos-network-monitor-9efb

# 2. 运行安装程序
chmod +x Install.command
./Install.command

# 按提示选择是否开机启动
# 按提示选择是否立即启动
```

## 手动安装步骤

```bash
# 1. 安装到应用目录
mkdir -p ~/Applications/ByteFlow
cp -r * ~/Applications/ByteFlow/
cd ~/Applications/ByteFlow

# 2. 安装 Python 依赖
pip3 install -r requirements.txt

# 3. 给脚本执行权限
chmod +x start.sh stop.sh Install.command

# 4. 启动应用
./start.sh

# 5. 打开浏览器
open http://127.0.0.1:8787
```

## 权限配置

### 1. 终端权限（必需）

**系统偏好设置 → 安全性与隐私 → 隐私 → 完全磁盘访问**

添加以下应用之一：
- `/Applications/Utilities/Terminal.app`
- `/Applications/iTerm.app`
- 您使用的其他终端应用

**为什么需要**: `nettop` 命令需要访问网络信息

### 2. Gatekeeper 处理

首次运行可能提示"无法验证开发者"：

**方法1**（推荐）:
```bash
右键点击 ByteFlow.command → 打开 → 确认打开
```

**方法2**:
```bash
xattr -d com.apple.quarantine ~/Applications/ByteFlow/ByteFlow.command
xattr -d com.apple.quarantine ~/Applications/ByteFlow/*.py
xattr -d com.apple.quarantine ~/Applications/ByteFlow/*.sh
```

**方法3**: 系统偏好设置 → 安全性与隐私 → 通用 → "仍要打开"

## 开机启动配置

### 自动配置（安装脚本已处理）

如果安装时选择了开机启动，LaunchAgent 已自动配置。

### 手动配置

```bash
# 1. 加载 LaunchAgent
launchctl load ~/Library/LaunchAgents/com.byteflow.agent.plist

# 2. 启动服务
launchctl start com.byteflow.agent

# 3. 检查状态
launchctl list | grep byteflow

# 4. 查看日志
tail -f ~/Applications/ByteFlow/logs/stderr.log
```

### 禁用开机启动

```bash
launchctl unload ~/Library/LaunchAgents/com.byteflow.agent.plist
rm ~/Library/LaunchAgents/com.byteflow.agent.plist
```

## 功能测试清单

### ✅ 基础功能

- [ ] 启动成功（collector + API）
- [ ] Web UI 可访问 (http://127.0.0.1:8787)
- [ ] 应用列表显示
- [ ] 点击应用打开详情模态框
- [ ] 图表显示正常
- [ ] 自动刷新工作正常

### ✅ 新功能测试

#### 1. IP 过滤设置
```bash
# 测试配置API
curl http://127.0.0.1:8787/api/config

# 更新配置
curl -X POST http://127.0.0.1:8787/api/config \
  -H "Content-Type: application/json" \
  -d '{"hide_loopback": true, "hide_private": true}'

# 验证配置已保存
cat ~/Applications/ByteFlow/byteflow_config.json
```

- [ ] 配置文件生成
- [ ] 配置API响应正常
- [ ] 配置持久化（重启后保留）

#### 2. Mac App + 安装
- [ ] Install.command 运行成功
- [ ] 文件复制到 ~/Applications/ByteFlow
- [ ] 依赖安装成功
- [ ] 快捷方式创建成功
- [ ] LaunchAgent plist 创建（如选择开机启动）

#### 3. 30天数据保留
```bash
# 查看清理日志
tail -f ~/Applications/ByteFlow/logs/stderr.log | grep "清理"

# 手动触发（修改时间测试）
# 或等待运行1小时后检查
```

- [ ] 清理任务执行
- [ ] 日志记录清理操作
- [ ] 旧数据被删除

#### 4. 性能优化
```bash
# 测试采样间隔配置
curl -X POST http://127.0.0.1:8787/api/config \
  -d '{"sample_interval": 2}'

# 重启collector使配置生效
./stop.sh && ./start.sh

# 查看24h数据点数量
curl http://127.0.0.1:8787/api/history/Chrome?range=24h | \
  python3 -m json.tool | grep timestamp | wc -l
```

- [ ] 采样间隔可配置
- [ ] 重启后生效
- [ ] 图表数据点数量合理（≤1000）

#### 5. 进程 Drill-Down
```bash
# 测试进程详情API
curl http://127.0.0.1:8787/api/process_details/Cursor?range=24h
```

- [ ] API 返回进程列表
- [ ] 显示各进程流量占比
- [ ] 合并前的Helper进程可见

#### 6. 流量归属提示
```bash
# 测试工具函数
python3 -c "
from utils import is_loopback, is_private, detect_vpn_interface
print('Loopback:', is_loopback('127.0.0.1'))
print('Private:', is_private('192.168.1.1'))
print('VPN:', detect_vpn_interface('utun0'))
"
```

- [ ] IP 分类函数工作正常
- [ ] VPN/代理检测正确
- [ ] 入站/出站判断合理

#### 7. 异常标记
```bash
# 查看异常标记
curl http://127.0.0.1:8787/api/spike_markers?range=24h
```

- [ ] API 返回标记列表
- [ ] 记录峰值丢弃事件
- [ ] 记录首次进程
- [ ] 记录计数器重置

#### 8. 菜单栏应用
```bash
# 启动菜单栏应用
python3 ~/Applications/ByteFlow/menubar.py

# 或后台启动
nohup python3 ~/Applications/ByteFlow/menubar.py &
```

- [ ] 菜单栏图标显示
- [ ] 总速率更新
- [ ] Top 应用列表显示
- [ ] 点击"打开主界面"跳转Web UI
- [ ] 退出功能正常

## 故障排除

### nettop 权限错误
```
错误: nettop: Operation not permitted
```
**解决**: 授予终端"完全磁盘访问"权限（见上方权限配置）

### rumps 安装失败
```
错误: No module named 'rumps'
```
**解决**:
```bash
pip3 install rumps
# 或
python3 -m pip install --user rumps
```

### LaunchAgent 不启动
```bash
# 检查 plist 语法
plutil -lint ~/Library/LaunchAgents/com.byteflow.agent.plist

# 查看系统日志
log show --predicate 'subsystem == "com.apple.launchd"' --last 1h | grep byteflow

# 手动加载
launchctl load -w ~/Library/LaunchAgents/com.byteflow.agent.plist
```

### 端口被占用
```
错误: Address already in use: 8787
```
**解决**:
```bash
# 查找占用进程
lsof -i :8787

# 停止旧进程
./stop.sh

# 或强制杀死
pkill -f "python.*api.py"
```

### 数据库锁定
```
错误: database is locked
```
**解决**:
```bash
# 停止所有服务
./stop.sh

# 确认没有进程使用数据库
lsof byteflow.db

# 重启
./start.sh
```

## 卸载

```bash
# 1. 停止服务
~/Applications/ByteFlow/stop.sh

# 2. 卸载 LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.byteflow.agent.plist
rm ~/Library/LaunchAgents/com.byteflow.agent.plist

# 3. 删除应用目录
rm -rf ~/Applications/ByteFlow

# 4. 删除数据（可选）
# 注意：这会删除所有流量历史数据
rm ~/Applications/ByteFlow/byteflow.db
rm ~/Applications/ByteFlow/byteflow_config.json
```

## 验证成功

所有测试通过后，您应该看到：

1. ✅ Web UI 正常运行
2. ✅ 实时数据采集和显示
3. ✅ 历史图表可查看
4. ✅ 配置可保存和加载
5. ✅ 进程详情可展开
6. ✅ 异常事件有标记
7. ✅ 菜单栏显示实时速率
8. ✅ 开机自动启动（如配置）

## 获取帮助

- GitHub Issues: https://github.com/Freegxx/byteflow/issues
- 功能文档: `FEATURES_GUIDE.md`
- 架构文档: `ARCHITECTURE.md`
- 准确性说明: `ACCURACY_FIX.md`

---

**测试日期**: _________  
**macOS 版本**: _________  
**Python 版本**: _________  
**测试结果**: ☐ 通过 ☐ 部分通过 ☐ 失败  
**备注**: ___________________________________
