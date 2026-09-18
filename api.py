#!/usr/bin/env python3
"""
ByteFlow API Server - Web API 服务器
提供流量数据查询接口
"""

import sqlite3
import time
from typing import List, Dict, Any
from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
import os

DB_PATH = "byteflow.db"

app = FastAPI(title="ByteFlow API", description="macOS 网络流量监控 API")


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


if __name__ == "__main__":
    import uvicorn
    print("启动 ByteFlow API 服务器...")
    print("访问: http://127.0.0.1:8787")
    uvicorn.run(app, host="127.0.0.1", port=8787, log_level="info")
