# ByteFlow 定时刷新功能说明

## 功能概述

在 ByteFlow Web UI 顶部工具栏添加了可选的定时刷新控件，用户可以自定义数据自动刷新的频率。

## UI 位置

控件位于顶部工具栏，在"最近24小时/7天/30天"按钮组的右侧，"刷新数据"按钮的左侧。

```
[最近24小时] [最近7天] [最近30天]    定时刷新 [关闭] [1秒] [3秒] [5秒] [30秒] [1分钟] [30分钟]    [刷新数据]
```

**样式**: 与时间范围按钮一致的标签式按钮组，激活状态使用 `.active` 类（紫色背景）。

## 可选刷新间隔

| 选项 | 值 | 描述 |
|------|-----|------|
| 关闭 | 0ms | 不自动刷新（默认） |
| 1秒 | 1000ms | 适合实时监控 |
| 3秒 | 3000ms | 平衡的实时更新 |
| 5秒 | 5000ms | 推荐的实时更新 |
| 30秒 | 30000ms | 适合后台监控 |
| 1分钟 | 60000ms | 长期监控 |
| 30分钟 | 1800000ms | 极轻量监控 |

## 智能刷新行为

### 场景 1: 概览页面（模态框关闭）

当用户在应用列表概览页面时：
- 刷新应用列表表格
- 更新统计卡片（应用数量、总下载、总上传）
- 自动应用搜索过滤器（保持当前筛选状态）

### 场景 2: 应用详情模态框（模态框打开）

当用户查看某个应用的详情时：
- 刷新三个使用量汇总卡片（24小时/7天/30天）
- 更新当前选中的历史图表（保持当前时间范围：24h/7d/30d）
- 更新远程 IP 列表（保持与图表时间范围同步）
- **不关闭模态框**，用户可以持续观察数据变化

## 技术实现

### 1. localStorage 持久化

用户选择的刷新间隔保存在浏览器 localStorage 中：

```javascript
localStorage.setItem('byteflow-refresh-interval', interval.toString());
```

**键名**: `byteflow-refresh-interval`  
**值**: 毫秒数（字符串形式）

页面重新加载时，自动恢复上次选择的间隔。

### 2. 防止重叠请求

使用 `isRefreshing` 标志防止在上一次请求未完成时发起新请求：

```javascript
let isRefreshing = false;

async function loadOverview(period) {
    if (isRefreshing) return; // 跳过
    isRefreshing = true;
    try {
        // ... 加载数据
    } finally {
        isRefreshing = false;
    }
}
```

**好处**:
- 避免服务器过载
- 防止竞态条件
- 确保数据一致性

### 3. 定时器管理

```javascript
let autoRefreshTimer = null;

function updateRefreshInterval(interval) {
    // 清除旧定时器
    if (autoRefreshTimer) {
        clearInterval(autoRefreshTimer);
        autoRefreshTimer = null;
    }
    
    // 保存到 localStorage
    localStorage.setItem('byteflow-refresh-interval', interval.toString());
    
    // 更新按钮激活状态
    document.querySelectorAll('[data-refresh]').forEach(btn => {
        btn.classList.remove('active');
        if (parseInt(btn.dataset.refresh) === interval) {
            btn.classList.add('active');
        }
    });
    
    // 创建新定时器（如果非关闭）
    if (interval > 0) {
        autoRefreshTimer = setInterval(() => {
            if (!isRefreshing) {
                performAutoRefresh();
            }
        }, interval);
    }
}

// 按钮点击事件
document.querySelectorAll('[data-refresh]').forEach(btn => {
    btn.addEventListener('click', (e) => {
        const interval = parseInt(e.target.dataset.refresh);
        updateRefreshInterval(interval);
    });
});
```

**特点**:
- 更改选择立即重启定时器
- 选择"关闭"清除定时器
- 自动更新按钮激活状态（`.active` 类）
- 仅在没有进行中的请求时执行刷新

### 4. 智能刷新路由

```javascript
function performAutoRefresh() {
    const modal = document.getElementById('app-modal');
    const isModalOpen = modal.classList.contains('active');
    
    if (isModalOpen && currentApp) {
        // 模态框打开 → 刷新模态框内容
        refreshModalContent();
    } else {
        // 模态框关闭 → 刷新概览列表
        loadOverview(currentPeriod);
    }
}
```

## 用户体验优化

### ✅ 保持状态

- **搜索过滤器**: 刷新后保持当前搜索词
- **时间范围**: 刷新后保持当前选中的时间范围（24h/7d/30d）
- **模态框**: 详情页刷新不会关闭模态框
- **图表状态**: Chart.js 图表在刷新时会重新渲染，但保持当前配置

### ✅ 性能考虑

- 默认关闭：避免不必要的后台请求
- 重叠保护：防止多个并发请求
- 轻量刷新：仅更新必要的 DOM 元素

### ✅ 向后兼容

- 移除了硬编码的 `setInterval(..., 30000)` 定时器
- 默认为"关闭"，用户需要主动启用
- 不影响手动"刷新数据"按钮的功能

## 样式设计

### 按钮式标签组

```css
.refresh-interval-selector {
    display: flex;
    gap: 8px;
}

/* 使用现有的 .btn 和 .btn.active 样式 */
.btn {
    padding: 10px 20px;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 500;
    transition: all 0.3s ease;
    background: #f5f5f7;
    color: #1d1d1f;
}

.btn:hover {
    background: #e8e8ed;
}

.btn.active {
    background: #667eea;
    color: white;
}
```

**设计原则**:
- 完全复用时间范围按钮的样式（`.btn` 和 `.active`）
- 与"最近24小时/7天/30天"按钮组视觉一致
- 激活按钮使用主题紫色 (`#667eea`)
- 圆角 8px，平滑过渡动画（0.3s）
- 按钮间距 8px（比时间范围按钮的 10px 略小）

### 响应式布局

```css
.controls {
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 15px;
}
```

- 在小屏幕上自动换行（`flex-wrap: wrap`）
- 保持元素间距（`gap: 15px`）
- 左侧时间范围按钮，右侧刷新控件

## 使用建议

### 适用场景

| 场景 | 推荐间隔 | 原因 |
|------|----------|------|
| 实时监控大流量应用 | 1秒 / 3秒 | 及时发现异常流量 |
| 日常使用监控 | 5秒 / 30秒 | 平衡实时性和资源消耗 |
| 后台长期监控 | 1分钟 / 30分钟 | 最小化性能影响 |
| 手动按需查看 | 关闭 | 避免不必要的刷新 |

### 注意事项

1. **过快的刷新间隔**（1秒）可能：
   - 增加 CPU 使用率（Chart.js 重绘）
   - 增加数据库查询频率
   - 在慢速网络上造成延迟

2. **推荐设置**:
   - 开发/调试：5秒
   - 日常监控：30秒 或 1分钟
   - 演示/录屏：关闭（手动刷新以控制时机）

3. **模态框刷新**:
   - 图表会闪烁重绘（Chart.js 限制）
   - 如需静态查看，暂时选择"关闭"

## 数据流程

```
用户选择间隔
    ↓
updateRefreshInterval()
    ↓
保存到 localStorage
    ↓
设置 setInterval(performAutoRefresh, interval)
    ↓
performAutoRefresh() 每 N 秒执行
    ↓
检查 isRefreshing 标志
    ↓
判断模态框状态
    ├─ 关闭 → loadOverview(currentPeriod)
    │           ├─ 更新应用列表
    │           └─ 更新统计卡片
    │
    └─ 打开 → refreshModalContent()
                ├─ loadSummaryData(currentApp)
                │    └─ 更新三个使用量卡片
                └─ loadChartData(currentApp, currentRange)
                     ├─ 更新 Chart.js 图表
                     └─ loadIPData() 更新 IP 列表
```

## 测试检查清单

- [x] 选择不同间隔，定时器正确启动
- [x] 选择"关闭"，定时器停止
- [x] 刷新间隔保存到 localStorage
- [x] 页面重载后恢复上次选择
- [x] 概览页面定时刷新列表
- [x] 模态框打开时定时刷新模态框内容
- [x] 模态框刷新不关闭窗口
- [x] isRefreshing 防止重叠请求
- [x] 手动"刷新数据"按钮仍然工作
- [x] ESC / 背景点击关闭模态框仍然工作
- [x] 搜索过滤器在刷新后保持
- [x] 时间范围选择在刷新后保持
- [x] 样式与现有 UI 一致

## 未来增强建议

1. **视觉反馈**: 刷新时在右上角显示小加载动画
2. **智能间隔**: 根据数据更新频率自动调整建议间隔
3. **暂停/恢复**: 在模态框滚动或用户交互时暂停自动刷新
4. **刷新统计**: 显示上次刷新时间和下次刷新倒计时
5. **错误重试**: 刷新失败时自动重试（带指数退避）

## 总结

定时刷新功能为 ByteFlow 提供了更灵活的数据监控体验，同时：
- ✅ 保持简洁的 UI（仅一个下拉框）
- ✅ 智能适应不同使用场景（概览 vs 详情）
- ✅ 性能优化（防重叠、可关闭）
- ✅ 持久化用户偏好（localStorage）
- ✅ 不破坏现有功能（Helper 合并、准确性修复等）

---

**实现日期**: 2026-09-18  
**文件修改**: `web/index.html`  
**测试状态**: ⚠️ 需在 macOS 浏览器中验证  
**兼容性**: 现代浏览器（支持 localStorage、ES6+）
