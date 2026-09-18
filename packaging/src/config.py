#!/usr/bin/env python3
"""
ByteFlow Configuration Management
配置管理模块
"""

import json
import os
from typing import Dict, Any

CONFIG_FILE = "byteflow_config.json"

DEFAULT_CONFIG = {
    # IP 过滤设置
    "hide_loopback": False,
    "hide_private": False,
    "merge_ipv4_24": False,
    
    # 采样设置
    "sample_interval": 1,  # 秒：1, 2, 5
    
    # 数据保留
    "retention_days": 30,
    
    # 性能设置
    "chart_max_points": 1000,
}


class Config:
    """配置管理类"""
    
    def __init__(self, config_path: str = CONFIG_FILE):
        self.config_path = config_path
        self.config = self.load()
    
    def load(self) -> Dict[str, Any]:
        """加载配置文件"""
        if os.path.exists(self.config_path):
            try:
                with open(self.config_path, 'r', encoding='utf-8') as f:
                    loaded = json.load(f)
                    # 合并默认配置（添加新字段）
                    config = DEFAULT_CONFIG.copy()
                    config.update(loaded)
                    return config
            except Exception as e:
                print(f"警告: 加载配置文件失败: {e}, 使用默认配置")
                return DEFAULT_CONFIG.copy()
        return DEFAULT_CONFIG.copy()
    
    def save(self):
        """保存配置到文件"""
        try:
            with open(self.config_path, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"错误: 保存配置文件失败: {e}")
    
    def get(self, key: str, default=None):
        """获取配置项"""
        return self.config.get(key, default)
    
    def set(self, key: str, value):
        """设置配置项并保存"""
        self.config[key] = value
        self.save()
    
    def update(self, updates: Dict[str, Any]):
        """批量更新配置"""
        self.config.update(updates)
        self.save()
    
    def get_all(self) -> Dict[str, Any]:
        """获取所有配置"""
        return self.config.copy()


# 全局配置实例
_config_instance = None


def get_config() -> Config:
    """获取全局配置实例"""
    global _config_instance
    if _config_instance is None:
        _config_instance = Config()
    return _config_instance
