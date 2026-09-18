#!/usr/bin/env python3
"""
ByteFlow Menu Bar App
菜单栏应用 - 显示实时流量和top应用
"""

import sys
import os
import time
import sqlite3
import webbrowser
from threading import Thread

try:
    import rumps
except ImportError:
    print("错误: 需要安装 rumps: pip install rumps")
    sys.exit(1)

DB_PATH = "byteflow.db"
API_URL = "http://127.0.0.1:8787"

def format_rate(bytes_per_sec):
    """格式化速率"""
    for unit in ['B/s', 'KB/s', 'MB/s', 'GB/s']:
        if bytes_per_sec < 1024.0:
            return f"{bytes_per_sec:.1f} {unit}"
        bytes_per_sec /= 1024.0
    return f"{bytes_per_sec:.1f} TB/s"

class ByteFlowMenuBar(rumps.App):
    def __init__(self):
        super(ByteFlowMenuBar, self).__init__("📊", quit_button=None)
        self.menu = [
            "打开主界面",
            None,
            "总速率: --",
            None,
            "Top 应用",
            "  正在加载...",
            None,
            rumps.MenuItem("退出", callback=self.quit_app)
        ]
        
        # 启动更新线程
        self.update_thread = Thread(target=self.update_stats, daemon=True)
        self.update_thread.start()
    
    @rumps.clicked("打开主界面")
    def open_ui(self, _):
        webbrowser.open(API_URL)
    
    def quit_app(self, _):
        rumps.quit_application()
    
    def update_stats(self):
        """更新统计数据"""
        while True:
            try:
                conn = sqlite3.connect(DB_PATH)
                cursor = conn.cursor()
                
                # 获取最近1秒的数据
                now = int(time.time())
                cursor.execute("""
                    SELECT app_name, SUM(rate_in), SUM(rate_out)
                    FROM traffic_raw
                    WHERE timestamp >= ?
                    GROUP BY app_name
                    ORDER BY (SUM(rate_in) + SUM(rate_out)) DESC
                    LIMIT 5
                """, (now - 1,))
                
                top_apps = cursor.fetchall()
                conn.close()
                
                # 计算总速率
                total_rate = sum(row[1] + row[2] for row in top_apps)
                
                # 更新标题
                self.title = f"📊 {format_rate(total_rate)}"
                
                # 更新菜单
                new_menu = [
                    "打开主界面",
                    None,
                    f"总速率: {format_rate(total_rate)}",
                    None,
                    "Top 应用"
                ]
                
                for app_name, rate_in, rate_out in top_apps:
                    rate = rate_in + rate_out
                    new_menu.append(f"  {app_name}: {format_rate(rate)}")
                
                if not top_apps:
                    new_menu.append("  暂无数据")
                
                new_menu.extend([None, rumps.MenuItem("退出", callback=self.quit_app)])
                
                self.menu.clear()
                for item in new_menu:
                    if item is None:
                        self.menu.add(rumps.separator)
                    elif isinstance(item, rumps.MenuItem):
                        self.menu.add(item)
                    else:
                        self.menu.add(item)
                
            except Exception as e:
                print(f"更新菜单栏失败: {e}")
            
            time.sleep(2)  # 每2秒更新

if __name__ == "__main__":
    ByteFlowMenuBar().run()
