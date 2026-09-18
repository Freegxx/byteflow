# ByteFlow

macOS 按应用网络流量监控：原生桌面窗口、历史折线图、Universal DMG（Apple Silicon + Intel）。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/Freegxx/byteflow)](https://github.com/Freegxx/byteflow/releases)

## 功能

- 按应用统计上下行流量（基于 macOS `nettop`）
- 24 小时 / 7 天 / 30 天历史与折线图
- 应用详情：用量卡片、图表、远程 IP 列表
- Helper 进程合并到主应用、筛选与搜索
- 原生窗口（非浏览器）、可选菜单栏
- Universal DMG，开箱即用

## 下载安装

1. 打开 [Releases](https://github.com/Freegxx/byteflow/releases) 下载 `ByteFlow-universal.dmg`
2. 打开 DMG，将 `ByteFlow.app` 拖到「应用程序」
3. 若未公证：右键应用 → 打开 → 仍要打开
4. 建议授予终端 / 应用所需的磁盘与网络相关权限（按系统提示）

升级前若概览曾出现异常「假应用」，可先退出应用并删除旧数据目录后再测：

`~/Library/Application Support/ByteFlow/`

## 从源码运行（开发）

需要 macOS 与 Python 3.11+。详见仓库内 `packaging/` 与根目录构建脚本。

```bash
git clone https://github.com/Freegxx/byteflow.git
cd byteflow
# 开发与打包说明见 packaging/ 与 build_universal_dmg.command
```

构建 Universal DMG：

```bash
chmod +x build_universal_dmg.command
./build_universal_dmg.command
```

## 许可

[MIT](LICENSE) © 2026 G X

## 反馈

Issue 与 Pull Request 欢迎直接提在本仓库。
