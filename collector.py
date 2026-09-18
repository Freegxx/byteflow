#!/usr/bin/env python3
"""
ByteFlow Network Collector - 网络流量采集器
使用 nettop 采集 macOS 每个进程的网络流量数据
"""

import subprocess
import time
import sqlite3
import sys
import platform
import re
from datetime import datetime, timedelta
from typing import Dict, Tuple
import signal
import os

DB_PATH = "byteflow.db"
SAMPLE_INTERVAL = 1  # 采样间隔（秒）


class NetworkCollector:
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.running = True
        self.previous_data = {}
        self.previous_connection_data = {}  # 存储连接级别的累积字节数
        self.init_database()
        
        # 注册信号处理
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        """处理退出信号"""
        print("\n正在停止采集器...")
        self.running = False
    
    @staticmethod
    def normalize_app_name(app_name: str) -> str:
        """
        标准化应用名称，合并辅助进程到主应用
        
        规则：
        1. 如果包含 ' Helper'（区分大小写），取之前的部分
        2. 清理尾部的不完整截断标记（如 ' (' 或 ' ('）
        3. 去除首尾空格
        
        示例：
        - 'Cursor Helper' → 'Cursor'
        - 'Cursor Helper (GPU)' → 'Cursor'
        - 'Chrome Helper (Renderer)' → 'Chrome'
        - '企业微信' → '企业微信' (保持不变)
        """
        normalized = app_name
        
        # 1. 如果包含 ' Helper'，截取之前的部分
        if ' Helper' in normalized:
            normalized = normalized.split(' Helper')[0]
        
        # 2. 清理尾部的不完整括号
        normalized = normalized.rstrip(' (')
        normalized = normalized.rstrip(' （')  # 中文括号
        
        # 3. 去除首尾空格
        normalized = normalized.strip()
        
        return normalized if normalized else app_name  # 防止返回空字符串
    
    def init_database(self):
        """初始化数据库表结构"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # 原始数据表（秒级精度，保留24小时）
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS traffic_raw (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                app_name TEXT NOT NULL,
                bundle_id TEXT,
                timestamp INTEGER NOT NULL,
                bytes_in INTEGER NOT NULL,
                bytes_out INTEGER NOT NULL,
                rate_in REAL NOT NULL,
                rate_out REAL NOT NULL
            )
        """)
        
        # 分钟聚合表（保留7天）
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS traffic_minute (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                app_name TEXT NOT NULL,
                bundle_id TEXT,
                timestamp INTEGER NOT NULL,
                bytes_in INTEGER NOT NULL,
                bytes_out INTEGER NOT NULL,
                UNIQUE(app_name, timestamp)
            )
        """)
        
        # 小时聚合表（保留30天）
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS traffic_hour (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                app_name TEXT NOT NULL,
                bundle_id TEXT,
                timestamp INTEGER NOT NULL,
                bytes_in INTEGER NOT NULL,
                bytes_out INTEGER NOT NULL,
                UNIQUE(app_name, timestamp)
            )
        """)
        
        # IP 流量表 - 秒级（保留24小时）
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS traffic_ip_raw (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                app_name TEXT NOT NULL,
                remote_ip TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                bytes_in INTEGER NOT NULL,
                bytes_out INTEGER NOT NULL
            )
        """)
        
        # IP 流量表 - 分钟级（保留7天）
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS traffic_ip_minute (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                app_name TEXT NOT NULL,
                remote_ip TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                bytes_in INTEGER NOT NULL,
                bytes_out INTEGER NOT NULL,
                UNIQUE(app_name, remote_ip, timestamp)
            )
        """)
        
        # IP 流量表 - 小时级（保留30天）
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS traffic_ip_hour (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                app_name TEXT NOT NULL,
                remote_ip TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                bytes_in INTEGER NOT NULL,
                bytes_out INTEGER NOT NULL,
                UNIQUE(app_name, remote_ip, timestamp)
            )
        """)
        
        # 创建索引以提高查询性能
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_raw_timestamp ON traffic_raw(timestamp)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_raw_app ON traffic_raw(app_name)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_minute_timestamp ON traffic_minute(timestamp)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_minute_app ON traffic_minute(app_name)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_hour_timestamp ON traffic_hour(timestamp)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_hour_app ON traffic_hour(app_name)")
        
        # IP 表索引
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_ip_raw_app ON traffic_ip_raw(app_name)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_ip_raw_timestamp ON traffic_ip_raw(timestamp)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_ip_minute_app ON traffic_ip_minute(app_name)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_ip_minute_timestamp ON traffic_ip_minute(timestamp)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_ip_hour_app ON traffic_ip_hour(app_name)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_ip_hour_timestamp ON traffic_ip_hour(timestamp)")
        
        conn.commit()
        conn.close()
        print(f"数据库初始化完成: {self.db_path}")
    
    def parse_nettop_output(self, output: str) -> Dict[str, Tuple[int, int]]:
        """
        解析 nettop CSV 输出，提取每个进程的字节数
        nettop -J 输出格式：,bytes_in,bytes_out,
                         进程名.PID,字节数,字节数,
        返回: {app_name: (bytes_in, bytes_out)}
        """
        traffic_data = {}
        lines = output.strip().split('\n')
        
        for line in lines:
            line = line.strip()
            
            # 跳过空行和表头
            if not line or line.startswith(',bytes_in,') or line == ',bytes_in,bytes_out,':
                continue
            
            # 按逗号分割 CSV
            parts = line.split(',')
            if len(parts) < 3:
                continue
            
            try:
                # 第一列是进程名（可能带.PID后缀）
                process_name = parts[0].strip()
                if not process_name:
                    continue
                
                # 去除 .PID 后缀（如 "mDNSResponder.193" -> "mDNSResponder"）
                app_name = re.sub(r'\.\d+$', '', process_name)
                
                # 标准化应用名称（合并 Helper 进程）
                app_name = self.normalize_app_name(app_name)
                
                # 最后两个数字字段是 bytes_in 和 bytes_out
                bytes_in = int(parts[1].strip())
                bytes_out = int(parts[2].strip())
                
                # 聚合同名应用
                if app_name in traffic_data:
                    prev_in, prev_out = traffic_data[app_name]
                    traffic_data[app_name] = (prev_in + bytes_in, prev_out + bytes_out)
                else:
                    traffic_data[app_name] = (bytes_in, bytes_out)
                    
            except (ValueError, IndexError) as e:
                # 跳过无法解析的行
                continue
        
        return traffic_data
    
    def parse_nettop_connections(self, output: str) -> Dict[str, Dict[str, Tuple[int, int]]]:
        """
        解析 nettop 连接级别输出，提取每个应用到每个远程 IP 的流量
        nettop -n (无 -P) 输出包含进程行和连接行
        返回: {app_name: {remote_ip: (bytes_in, bytes_out)}}
        """
        app_ip_traffic = {}
        current_app = None
        lines = output.strip().split('\n')
        
        for line in lines:
            line = line.strip()
            if not line or line.startswith(',bytes_in,'):
                continue
            
            parts = line.split(',')
            if len(parts) < 3:
                continue
            
            try:
                # 判断是进程行还是连接行
                if '<->' not in parts[0]:
                    # 进程行：Name.pid,bytes_in,bytes_out,
                    process_name = parts[0].strip()
                    if process_name:
                        # 去除 .PID 后缀并标准化应用名
                        app_name = re.sub(r'\.\d+$', '', process_name)
                        current_app = self.normalize_app_name(app_name)
                else:
                    # 连接行：tcp4 local<->remote,bytes_in,bytes_out,
                    if not current_app:
                        continue
                    
                    connection_str = parts[0].strip()
                    
                    # 提取远程 IP（在 <-> 之后，去除端口）
                    if '<->' in connection_str:
                        remote_part = connection_str.split('<->')[1]
                        # 去除端口号（可能是 IP:port 或 [IPv6]:port 格式）
                        if ':' in remote_part:
                            # IPv4 格式：IP:port
                            remote_ip = remote_part.rsplit(':', 1)[0]
                        else:
                            remote_ip = remote_part
                        
                        # 跳过通配符和空地址
                        if remote_ip in ('*', '', '0.0.0.0', '::'):
                            continue
                        
                        # 提取字节数
                        bytes_in = int(parts[1].strip())
                        bytes_out = int(parts[2].strip())
                        
                        # 使用完整连接字符串作为 key 计算增量
                        conn_key = f"{current_app}:{connection_str}"
                        
                        # 计算相对于上次的增量
                        delta_in = 0
                        delta_out = 0
                        if conn_key in self.previous_connection_data:
                            prev_in, prev_out = self.previous_connection_data[conn_key]
                            delta_in = max(0, bytes_in - prev_in)
                            delta_out = max(0, bytes_out - prev_out)
                        
                        # 保存当前累积值
                        self.previous_connection_data[conn_key] = (bytes_in, bytes_out)
                        
                        # 只有增量 > 0 才记录
                        if delta_in > 0 or delta_out > 0:
                            if current_app not in app_ip_traffic:
                                app_ip_traffic[current_app] = {}
                            
                            if remote_ip not in app_ip_traffic[current_app]:
                                app_ip_traffic[current_app][remote_ip] = (0, 0)
                            
                            prev_in, prev_out = app_ip_traffic[current_app][remote_ip]
                            app_ip_traffic[current_app][remote_ip] = (
                                prev_in + delta_in,
                                prev_out + delta_out
                            )
            
            except (ValueError, IndexError) as e:
                continue
        
        return app_ip_traffic
    
    def collect_nettop_data(self) -> Tuple[Dict[str, Tuple[int, int]], Dict[str, Dict[str, Tuple[int, int]]]]:
        """
        执行 nettop 命令并解析结果
        返回: (app_traffic, app_ip_traffic)
        - app_traffic: {app_name: (bytes_in, bytes_out)}
        - app_ip_traffic: {app_name: {remote_ip: (bytes_in, bytes_out)}}
        """
        try:
            # 使用 nettop -n (不带 -P) 获取连接级别数据
            # -n: 显示网络连接
            # -L 1: 采样1次
            # -J: 指定列
            # -x: 无单位
            result = subprocess.run(
                ['nettop', '-n', '-L', '1', '-J', 'bytes_in,bytes_out', '-x'],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode != 0:
                print(f"nettop 执行失败: {result.stderr}")
                return {}, {}
            
            # 解析应用级别流量（兼容原有格式）
            app_traffic = self.parse_nettop_output(result.stdout)
            
            # 解析连接级别流量（IP 级别）
            app_ip_traffic = self.parse_nettop_connections(result.stdout)
            
            return app_traffic, app_ip_traffic
        
        except subprocess.TimeoutExpired:
            print("nettop 执行超时")
            return {}, {}
        except FileNotFoundError:
            print("错误: 找不到 nettop 命令。请确保在 macOS 系统上运行。")
            sys.exit(1)
        except Exception as e:
            print(f"采集数据时出错: {e}")
            return {}, {}
    
    def save_traffic_data(self, traffic_data: Dict[str, Tuple[int, int]], timestamp: int):
        """保存流量数据到数据库"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        for app_name, (bytes_in, bytes_out) in traffic_data.items():
            # 计算速率（相对于上一次采样）
            rate_in = 0.0
            rate_out = 0.0
            
            if app_name in self.previous_data:
                prev_in, prev_out = self.previous_data[app_name]
                rate_in = max(0, bytes_in - prev_in) / SAMPLE_INTERVAL
                rate_out = max(0, bytes_out - prev_out) / SAMPLE_INTERVAL
            
            # 保存到原始数据表
            cursor.execute("""
                INSERT INTO traffic_raw (app_name, bundle_id, timestamp, bytes_in, bytes_out, rate_in, rate_out)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (app_name, None, timestamp, bytes_in, bytes_out, rate_in, rate_out))
        
        conn.commit()
        conn.close()
        
        # 更新上次数据
        self.previous_data = traffic_data
    
    def save_ip_traffic_data(self, app_ip_traffic: Dict[str, Dict[str, Tuple[int, int]]], timestamp: int):
        """保存 IP 级别流量数据到数据库"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        for app_name, ip_traffic in app_ip_traffic.items():
            for remote_ip, (bytes_in, bytes_out) in ip_traffic.items():
                # 保存增量数据到 IP 原始数据表
                cursor.execute("""
                    INSERT INTO traffic_ip_raw (app_name, remote_ip, timestamp, bytes_in, bytes_out)
                    VALUES (?, ?, ?, ?, ?)
                """, (app_name, remote_ip, timestamp, bytes_in, bytes_out))
        
        conn.commit()
        conn.close()
    
    def rollup_data(self):
        """数据汇总：将秒级数据聚合到分钟和小时"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        now = int(time.time())
        
        # 聚合到分钟（每分钟执行一次）
        minute_ago = now - 120  # 处理过去2分钟的数据
        minute_timestamp = (now // 60) * 60
        
        cursor.execute("""
            INSERT OR REPLACE INTO traffic_minute (app_name, bundle_id, timestamp, bytes_in, bytes_out)
            SELECT 
                app_name,
                bundle_id,
                ? as timestamp,
                SUM(bytes_in) as bytes_in,
                SUM(bytes_out) as bytes_out
            FROM traffic_raw
            WHERE timestamp >= ? AND timestamp < ?
            GROUP BY app_name
        """, (minute_timestamp - 60, minute_timestamp - 60, minute_timestamp))
        
        # 聚合到小时（每小时执行一次）
        hour_timestamp = (now // 3600) * 3600
        hour_ago = hour_timestamp - 3600
        
        cursor.execute("""
            INSERT OR REPLACE INTO traffic_hour (app_name, bundle_id, timestamp, bytes_in, bytes_out)
            SELECT 
                app_name,
                bundle_id,
                ? as timestamp,
                SUM(bytes_in) as bytes_in,
                SUM(bytes_out) as bytes_out
            FROM traffic_minute
            WHERE timestamp >= ? AND timestamp < ?
            GROUP BY app_name
        """, (hour_ago, hour_ago, hour_timestamp))
        
        # IP 数据汇总：秒级 -> 分钟级
        cursor.execute("""
            INSERT OR REPLACE INTO traffic_ip_minute (app_name, remote_ip, timestamp, bytes_in, bytes_out)
            SELECT 
                app_name,
                remote_ip,
                ? as timestamp,
                SUM(bytes_in) as bytes_in,
                SUM(bytes_out) as bytes_out
            FROM traffic_ip_raw
            WHERE timestamp >= ? AND timestamp < ?
            GROUP BY app_name, remote_ip
        """, (minute_timestamp - 60, minute_timestamp - 60, minute_timestamp))
        
        # IP 数据汇总：分钟级 -> 小时级
        cursor.execute("""
            INSERT OR REPLACE INTO traffic_ip_hour (app_name, remote_ip, timestamp, bytes_in, bytes_out)
            SELECT 
                app_name,
                remote_ip,
                ? as timestamp,
                SUM(bytes_in) as bytes_in,
                SUM(bytes_out) as bytes_out
            FROM traffic_ip_minute
            WHERE timestamp >= ? AND timestamp < ?
            GROUP BY app_name, remote_ip
        """, (hour_ago, hour_ago, hour_timestamp))
        
        conn.commit()
        conn.close()
    
    def cleanup_old_data(self):
        """清理过期数据"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        now = int(time.time())
        
        # 删除24小时前的原始数据
        cursor.execute("DELETE FROM traffic_raw WHERE timestamp < ?", (now - 24 * 3600,))
        cursor.execute("DELETE FROM traffic_ip_raw WHERE timestamp < ?", (now - 24 * 3600,))
        
        # 删除7天前的分钟数据
        cursor.execute("DELETE FROM traffic_minute WHERE timestamp < ?", (now - 7 * 24 * 3600,))
        cursor.execute("DELETE FROM traffic_ip_minute WHERE timestamp < ?", (now - 7 * 24 * 3600,))
        
        # 删除30天前的小时数据
        cursor.execute("DELETE FROM traffic_hour WHERE timestamp < ?", (now - 30 * 24 * 3600,))
        cursor.execute("DELETE FROM traffic_ip_hour WHERE timestamp < ?", (now - 30 * 24 * 3600,))
        
        conn.commit()
        conn.close()
    
    def run(self):
        """主采集循环"""
        print("ByteFlow 采集器已启动...")
        print(f"采样间隔: {SAMPLE_INTERVAL} 秒")
        print(f"数据库位置: {os.path.abspath(self.db_path)}")
        print("按 Ctrl+C 停止采集\n")
        
        iteration = 0
        
        while self.running:
            try:
                # 采集数据
                timestamp = int(time.time())
                traffic_data, app_ip_traffic = self.collect_nettop_data()
                
                if traffic_data:
                    self.save_traffic_data(traffic_data, timestamp)
                    print(f"[{datetime.fromtimestamp(timestamp).strftime('%H:%M:%S')}] "
                          f"采集了 {len(traffic_data)} 个应用的流量数据")
                
                # 保存 IP 级别数据
                if app_ip_traffic:
                    self.save_ip_traffic_data(app_ip_traffic, timestamp)
                    total_ips = sum(len(ips) for ips in app_ip_traffic.values())
                    if total_ips > 0:
                        print(f"  → 采集了 {total_ips} 个远程 IP 连接")
                
                # 每60秒执行一次汇总
                iteration += 1
                if iteration % 60 == 0:
                    print("执行数据汇总...")
                    self.rollup_data()
                
                # 每10分钟清理一次旧数据
                if iteration % 600 == 0:
                    print("清理过期数据...")
                    self.cleanup_old_data()
                
                # 等待下一次采样
                time.sleep(SAMPLE_INTERVAL)
            
            except Exception as e:
                print(f"采集循环出错: {e}")
                time.sleep(SAMPLE_INTERVAL)
        
        print("采集器已停止")


def check_macos():
    """检查是否在 macOS 上运行"""
    if platform.system() != "Darwin":
        print("错误: ByteFlow 只能在 macOS 系统上运行")
        print(f"当前系统: {platform.system()}")
        sys.exit(1)


def main():
    check_macos()
    
    collector = NetworkCollector(DB_PATH)
    collector.run()


if __name__ == "__main__":
    main()
