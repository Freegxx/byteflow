#!/usr/bin/env python3
"""
ByteFlow Utility Functions
工具函数模块
"""

import ipaddress
import re
from typing import Tuple, Optional

def is_loopback(ip: str) -> bool:
    """判断是否为回环地址"""
    try:
        addr = ipaddress.ip_address(ip)
        return addr.is_loopback
    except:
        return False

def is_private(ip: str) -> bool:
    """判断是否为私有/LAN地址"""
    try:
        addr = ipaddress.ip_address(ip)
        return addr.is_private or addr.is_link_local
    except:
        return False

def get_ipv4_24_network(ip: str) -> Optional[str]:
    """获取IPv4的/24网络地址"""
    try:
        addr = ipaddress.ip_address(ip)
        if addr.version == 4:
            network = ipaddress.ip_network(f"{ip}/24", strict=False)
            return str(network.network_address) + "/24"
    except:
        pass
    return None

def get_ipv6_48_network(ip: str) -> Optional[str]:
    """获取IPv6的/48网络地址（合理的聚合级别）"""
    try:
        addr = ipaddress.ip_address(ip)
        if addr.version == 6:
            network = ipaddress.ip_network(f"{ip}/48", strict=False)
            return str(network.network_address) + "/48"
    except:
        pass
    return None

def detect_vpn_interface(connection_str: str) -> bool:
    """检测是否为VPN/代理连接"""
    vpn_indicators = ['utun', 'ppp', 'ipsec', 'tun', 'tap']
    return any(indicator in connection_str.lower() for indicator in vpn_indicators)

def detect_proxy_port(port: int) -> bool:
    """检测是否为常见代理端口"""
    proxy_ports = [1080, 3128, 8080, 8118, 8888, 9050, 9150]
    return port in proxy_ports

def is_inbound(connection_str: str) -> bool:
    """简单启发式判断入站/出站（基于端口和连接方向）"""
    # 如果本地端口是知名服务端口，可能是入站
    try:
        if '<->' in connection_str:
            local_part = connection_str.split('<->')[0]
            if ':' in local_part:
                local_port = int(local_part.split(':')[-1])
                # 常见服务端口
                service_ports = [80, 443, 22, 21, 25, 110, 143, 993, 995]
                return local_port in service_ports
    except:
        pass
    return False

def format_bytes(bytes_val: int) -> str:
    """格式化字节数为人类可读格式"""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes_val < 1024.0:
            return f"{bytes_val:.2f} {unit}"
        bytes_val /= 1024.0
    return f"{bytes_val:.2f} PB"

def downsample_data(data: list, max_points: int) -> list:
    """对数据进行降采样"""
    if len(data) <= max_points:
        return data
    
    step = len(data) / max_points
    result = []
    for i in range(max_points):
        idx = int(i * step)
        result.append(data[idx])
    
    return result

def aggregate_by_bucket(data: list, num_buckets: int) -> list:
    """将数据聚合到指定数量的桶中（取最大值或平均值）"""
    if len(data) <= num_buckets:
        return data
    
    bucket_size = len(data) / num_buckets
    result = []
    
    for i in range(num_buckets):
        start = int(i * bucket_size)
        end = int((i + 1) * bucket_size)
        bucket_data = data[start:end]
        
        if bucket_data:
            # 对于流量数据，使用最大值更能反映峰值
            result.append(max(bucket_data, key=lambda x: x.get('bytes_in', 0) + x.get('bytes_out', 0)))
    
    return result
