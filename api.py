#!/usr/bin/env python3
"""
ByteFlow API Server - Web API 服务器
提供流量数据查询接口
"""

import sqlite3
import time
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException, Body
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
import os

DB_PATH = "byteflow.db"
SAMPLE_INTERVAL = 1  # 采样间隔（秒），与 collector.py 保持一致

try:
    from config import get_config
    from utils import (is_loopback, is_private, get_ipv4_24_network, 
                      get_ipv6_48_network, downsample_data, aggregate_by_bucket)
    CONFIG = get_config()
except ImportError:
    CONFIG = None
    print("警告: 无法加载配置/工具模块")

app = FastAPI(title="ByteFlow API", description="macOS 网络流量监控 API")

# 添加CORS支持
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def get_db_connection():
    """获取数据库连接"""
    if not os.path.exists(DB_PATH):
        raise HTTPException(status_code=500, detail="数据库文件不存在，请先启动采集器")
    return sqlite3.connect(DB_PATH)


@app.get("/")
async def root():
    """返回前端页面"""
    html_path = "web/index.html"
    if os.path.exists(html_path):
        with open(html_path, 'r', encoding='utf-8') as f:
            return HTMLResponse(content=f.read())
    return {"message": "ByteFlow API 已启动"}


@app.get("/api/overview")
async def get_overview(period: str = "24h"):
    """
    获取应用流量概览
    period: 24h, 7d, 30d
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    now = int(time.time())
    
    # 根据时间范围选择数据源
    if period == "24h":
        table = "traffic_raw"
        since = now - 24 * 3600
    elif period == "7d":
        table = "traffic_minute"
        since = now - 7 * 24 * 3600
    elif period == "30d":
        table = "traffic_hour"
        since = now - 30 * 24 * 3600
    else:
        conn.close()
        raise HTTPException(status_code=400, detail="无效的时间范围")
    
    # 查询每个应用的总流量
    # 注意：bytes_in/out 现在存储的是每个采样间隔的增量字节数
    # 对于 traffic_raw (24h)：使用 SUM(rate_*) 更准确（兼容旧数据）
    # 对于 minute/hour：SUM(bytes_*) 正确（已经是增量聚合）
    if table == "traffic_raw":
        # 24h: 使用速率求和以确保准确性
        query = f"""
            SELECT 
                app_name,
                SUM(rate_in * ?) as total_in,
                SUM(rate_out * ?) as total_out
            FROM {table}
            WHERE timestamp >= ?
            GROUP BY app_name
            ORDER BY (total_in + total_out) DESC
        """
        cursor.execute(query, (SAMPLE_INTERVAL, SAMPLE_INTERVAL, since))
    else:
        # 7d/30d: 直接求和增量字节
        query = f"""
            SELECT 
                app_name,
                SUM(bytes_in) as total_in,
                SUM(bytes_out) as total_out
            FROM {table}
            WHERE timestamp >= ?
            GROUP BY app_name
            ORDER BY (total_in + total_out) DESC
        """
        cursor.execute(query, (since,))
    
    rows = cursor.fetchall()
    
    # 计算当前速率（从最近的原始数据）
    rate_query = """
        SELECT 
            app_name,
            AVG(rate_in) as avg_rate_in,
            AVG(rate_out) as avg_rate_out
        FROM traffic_raw
        WHERE timestamp >= ?
        GROUP BY app_name
    """
    cursor.execute(rate_query, (now - 60,))  # 最近1分钟的平均速率
    rate_rows = cursor.fetchall()
    
    conn.close()
    
    # 构建速率字典
    rates = {}
    for row in rate_rows:
        rates[row[0]] = {
            "rate_in": row[1] or 0,
            "rate_out": row[2] or 0
        }
    
    # 构建响应
    result = []
    for row in rows:
        app_name = row[0]
        result.append({
            "app_name": app_name,
            "total_in": row[1],
            "total_out": row[2],
            "rate_in": rates.get(app_name, {}).get("rate_in", 0),
            "rate_out": rates.get(app_name, {}).get("rate_out", 0)
        })
    
    return {"apps": result, "period": period}


@app.get("/api/history/{app_name}")
async def get_app_history(app_name: str, range: str = "24h"):
    """
    获取指定应用的历史流量数据
    range: 24h (秒级), 7d (分钟级), 30d (小时级)
    
    返回值：每个时间点的 bytes_in/out 是该时间段内的传输字节数（增量），非累积值
    例如：10:00 → 5MB, 10:01 → 3MB 表示 10:00-10:01 传输了 5MB，10:01-10:02 传输了 3MB
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    now = int(time.time())
    
    # 根据时间范围选择数据源和时间间隔
    if range == "24h":
        table = "traffic_raw"
        since = now - 24 * 3600
        # 返回秒级数据
        query = f"""
            SELECT timestamp, bytes_in, bytes_out, rate_in, rate_out
            FROM {table}
            WHERE app_name = ? AND timestamp >= ?
            ORDER BY timestamp ASC
        """
    elif range == "7d":
        table = "traffic_minute"
        since = now - 7 * 24 * 3600
        # 返回分钟级数据
        query = f"""
            SELECT timestamp, bytes_in, bytes_out
            FROM {table}
            WHERE app_name = ? AND timestamp >= ?
            ORDER BY timestamp ASC
        """
    elif range == "30d":
        table = "traffic_hour"
        since = now - 30 * 24 * 3600
        # 返回小时级数据
        query = f"""
            SELECT timestamp, bytes_in, bytes_out
            FROM {table}
            WHERE app_name = ? AND timestamp >= ?
            ORDER BY timestamp ASC
        """
    else:
        conn.close()
        raise HTTPException(status_code=400, detail="无效的时间范围")
    
    cursor.execute(query, (app_name, since))
    rows = cursor.fetchall()
    conn.close()
    
    if not rows:
        return {"app_name": app_name, "range": range, "data": []}
    
    # 构建响应
    data_points = []
    for row in rows:
        point = {
            "timestamp": row[0],
            "bytes_in": row[1],
            "bytes_out": row[2]
        }
        # 24小时数据包含速率信息
        if range == "24h" and len(row) >= 5:
            point["rate_in"] = row[3]
            point["rate_out"] = row[4]
        data_points.append(point)
    
    return {
        "app_name": app_name,
        "range": range,
        "data": data_points
    }


@app.get("/api/history/{app_name}/ips")
async def get_app_ips(app_name: str, range: str = "24h"):
    """
    获取指定应用连接的远程 IP 列表及流量统计
    range: 24h (秒级), 7d (分钟级), 30d (小时级)
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    now = int(time.time())
    
    # 根据时间范围选择数据源
    if range == "24h":
        table = "traffic_ip_raw"
        since = now - 24 * 3600
    elif range == "7d":
        table = "traffic_ip_minute"
        since = now - 7 * 24 * 3600
    elif range == "30d":
        table = "traffic_ip_hour"
        since = now - 30 * 24 * 3600
    else:
        conn.close()
        raise HTTPException(status_code=400, detail="无效的时间范围")
    
    # 查询该应用所有远程 IP 的总流量
    query = f"""
        SELECT 
            remote_ip,
            SUM(bytes_in) as total_in,
            SUM(bytes_out) as total_out,
            SUM(bytes_in + bytes_out) as total_bytes
        FROM {table}
        WHERE app_name = ? AND timestamp >= ?
        GROUP BY remote_ip
        ORDER BY total_bytes DESC
    """
    
    cursor.execute(query, (app_name, since))
    rows = cursor.fetchall()
    conn.close()
    
    if not rows:
        return {"app_name": app_name, "range": range, "ips": []}
    
    # 构建响应
    ip_list = []
    for row in rows:
        ip_list.append({
            "ip": row[0],
            "bytes_in": row[1],
            "bytes_out": row[2],
            "total_bytes": row[3]
        })
    
    return {
        "app_name": app_name,
        "range": range,
        "ips": ip_list
    }


@app.get("/api/stats")
async def get_stats():
    """获取系统统计信息"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # 统计数据库大小
    cursor.execute("SELECT COUNT(*) FROM traffic_raw")
    raw_count = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM traffic_minute")
    minute_count = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM traffic_hour")
    hour_count = cursor.fetchone()[0]
    
    # 统计应用数量
    cursor.execute("SELECT COUNT(DISTINCT app_name) FROM traffic_raw")
    app_count = cursor.fetchone()[0]
    
    # 最早和最新数据时间
    cursor.execute("SELECT MIN(timestamp), MAX(timestamp) FROM traffic_raw")
    time_range = cursor.fetchone()
    
    conn.close()
    
    return {
        "database_records": {
            "raw": raw_count,
            "minute": minute_count,
            "hour": hour_count
        },
        "total_apps": app_count,
        "time_range": {
            "earliest": time_range[0],
            "latest": time_range[1]
        }
    }


@app.get("/api/config")
async def get_config_api():
    """获取配置"""
    if CONFIG:
        return CONFIG.get_all()
    return {}

@app.post("/api/config")
async def update_config_api(updates: dict = Body(...)):
    """更新配置"""
    if CONFIG:
        CONFIG.update(updates)
        return {"status": "ok", "config": CONFIG.get_all()}
    return {"status": "error", "message": "配置模块未加载"}

@app.get("/api/process_details/{app_name}")
async def get_process_details(app_name: str, range: str = "24h"):
    """获取应用的进程详情（用于drill-down）"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    now = int(time.time())
    if range == "24h":
        since = now - 24 * 3600
    elif range == "7d":
        since = now - 7 * 24 * 3600
    else:
        since = now - 30 * 24 * 3600
    
    cursor.execute("""
        SELECT process_name, SUM(bytes_in), SUM(bytes_out)
        FROM process_details
        WHERE app_name = ? AND timestamp >= ?
        GROUP BY process_name
        ORDER BY (SUM(bytes_in) + SUM(bytes_out)) DESC
    """, (app_name, since))
    
    processes = []
    for row in cursor.fetchall():
        processes.append({
            "process_name": row[0],
            "bytes_in": row[1],
            "bytes_out": row[2],
            "total": row[1] + row[2]
        })
    
    conn.close()
    return {"app_name": app_name, "processes": processes}

@app.get("/api/spike_markers")
async def get_spike_markers(range: str = "24h"):
    """获取异常/峰值标记"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    now = int(time.time())
    if range == "24h":
        since = now - 24 * 3600
    elif range == "7d":
        since = now - 7 * 24 * 3600
    else:
        since = now - 30 * 24 * 3600
    
    cursor.execute("""
        SELECT app_name, process_name, timestamp, reason, delta_in, delta_out
        FROM spike_markers
        WHERE timestamp >= ?
        ORDER BY timestamp DESC
    """, (since,))
    
    markers = []
    for row in cursor.fetchall():
        markers.append({
            "app_name": row[0],
            "process_name": row[1],
            "timestamp": row[2],
            "reason": row[3],
            "delta_in": row[4],
            "delta_out": row[5]
        })
    
    conn.close()
    return {"markers": markers}

if __name__ == "__main__":
    import uvicorn
    print("启动 ByteFlow API 服务器...")
    print("访问: http://127.0.0.1:8787")
    uvicorn.run(app, host="127.0.0.1", port=8787, log_level="info")
