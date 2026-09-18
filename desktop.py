#!/usr/bin/env python3
"""
ByteFlow Desktop Application
使用 pywebview 创建原生桌面窗口
"""

import sys
import time
import subprocess
import os
import signal
import requests
import webview
from pathlib import Path

# 数据目录
DATA_DIR = Path.home() / "Library" / "Application Support" / "ByteFlow"
LOGS_DIR = DATA_DIR / "logs"
PIDS_DIR = DATA_DIR / ".pids"

# 确保目录存在
DATA_DIR.mkdir(parents=True, exist_ok=True)
LOGS_DIR.mkdir(exist_ok=True)
PIDS_DIR.mkdir(exist_ok=True)

# 服务配置
API_URL = "http://127.0.0.1:8787"
MAX_STARTUP_WAIT = 10  # 秒

# 全局进程引用
collector_process = None
api_process = None


def get_script_dir():
    """获取脚本所在目录（适配 .app bundle）"""
    if getattr(sys, 'frozen', False):
        # PyInstaller bundle
        return Path(sys._MEIPASS)
    else:
        # 开发环境或直接运行
        return Path(__file__).parent.absolute()


def start_background_services():
    """启动后台服务（collector + API）"""
    global collector_process, api_process
    
    script_dir = get_script_dir()
    collector_log = LOGS_DIR / "collector.log"
    api_log = LOGS_DIR / "api.log"
    
    print(f"启动后台服务...")
    print(f"  脚本目录: {script_dir}")
    print(f"  数据目录: {DATA_DIR}")
    
    # 设置环境变量
    env = os.environ.copy()
    env['PYTHONUNBUFFERED'] = '1'
    env['BYTEFLOW_DATA_DIR'] = str(DATA_DIR)
    
    # 启动 collector
    collector_script = script_dir / "collector.py"
    if collector_script.exists():
        print(f"  启动 collector: {collector_script}")
        with open(collector_log, 'w') as log_file:
            collector_process = subprocess.Popen(
                [sys.executable, str(collector_script)],
                stdout=log_file,
                stderr=subprocess.STDOUT,
                env=env,
                cwd=str(script_dir)
            )
        # 保存 PID
        (PIDS_DIR / "collector.pid").write_text(str(collector_process.pid))
    else:
        print(f"  警告: 未找到 collector.py")
    
    # 等待一秒
    time.sleep(1)
    
    # 启动 API
    api_script = script_dir / "api.py"
    if api_script.exists():
        print(f"  启动 API: {api_script}")
        with open(api_log, 'w') as log_file:
            api_process = subprocess.Popen(
                [sys.executable, str(api_script)],
                stdout=log_file,
                stderr=subprocess.STDOUT,
                env=env,
                cwd=str(script_dir)
            )
        # 保存 PID
        (PIDS_DIR / "api.pid").write_text(str(api_process.pid))
    else:
        print(f"  警告: 未找到 api.py")


def wait_for_api_ready(max_wait=MAX_STARTUP_WAIT):
    """等待 API 服务就绪"""
    print(f"等待 API 服务启动 (最多 {max_wait} 秒)...")
    
    for i in range(max_wait * 2):  # 每 0.5 秒检查一次
        try:
            response = requests.get(f"{API_URL}/api/overview?period=24h", timeout=1)
            if response.status_code == 200:
                print(f"✓ API 服务已就绪")
                return True
        except (requests.ConnectionError, requests.Timeout):
            pass
        
        time.sleep(0.5)
    
    print(f"✗ API 服务启动超时")
    return False


def stop_background_services():
    """停止后台服务"""
    global collector_process, api_process
    
    print("停止后台服务...")
    
    # 停止 collector
    if collector_process:
        try:
            collector_process.terminate()
            collector_process.wait(timeout=5)
            print("  ✓ collector 已停止")
        except subprocess.TimeoutExpired:
            collector_process.kill()
            print("  ✓ collector 已强制停止")
        except Exception as e:
            print(f"  警告: collector 停止失败: {e}")
    
    # 停止 API
    if api_process:
        try:
            api_process.terminate()
            api_process.wait(timeout=5)
            print("  ✓ API 已停止")
        except subprocess.TimeoutExpired:
            api_process.kill()
            print("  ✓ API 已强制停止")
        except Exception as e:
            print(f"  警告: API 停止失败: {e}")
    
    # 清理 PID 文件
    for pid_file in [PIDS_DIR / "collector.pid", PIDS_DIR / "api.pid"]:
        if pid_file.exists():
            pid_file.unlink()


def on_window_closing():
    """窗口关闭事件处理"""
    print("窗口关闭，清理资源...")
    stop_background_services()


def check_existing_services():
    """检查是否有已运行的服务"""
    try:
        response = requests.get(f"{API_URL}/api/overview?period=24h", timeout=1)
        if response.status_code == 200:
            print("检测到已运行的服务，将复用")
            return True
    except:
        pass
    return False


def main():
    """主函数"""
    print("=" * 50)
    print("ByteFlow Desktop - 原生桌面应用")
    print("=" * 50)
    print()
    
    # 检查是否已有服务运行
    services_already_running = check_existing_services()
    
    if not services_already_running:
        # 启动后台服务
        start_background_services()
        
        # 等待 API 就绪
        if not wait_for_api_ready():
            print()
            print("错误: API 服务启动失败")
            print(f"请检查日志: {LOGS_DIR}")
            stop_background_services()
            sys.exit(1)
    else:
        print("使用已运行的服务")
    
    print()
    print("启动桌面窗口...")
    print(f"  URL: {API_URL}")
    print()
    
    try:
        # 创建桌面窗口（使用 WKWebView on macOS）
        window = webview.create_window(
            'ByteFlow - 网络流量监控',
            API_URL,
            width=1400,
            height=900,
            resizable=True,
            fullscreen=False,
            min_size=(1000, 700),
            confirm_close=False,
        )
        
        # 注册关闭事件
        window.events.closing += on_window_closing
        
        # 启动 GUI（阻塞直到窗口关闭）
        webview.start()
        
    except Exception as e:
        print(f"错误: 创建窗口失败: {e}")
        stop_background_services()
        sys.exit(1)
    
    print()
    print("ByteFlow 已退出")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n收到中断信号，正在退出...")
        stop_background_services()
        sys.exit(0)
    except Exception as e:
        print(f"\n\n错误: {e}")
        import traceback
        traceback.print_exc()
        stop_background_services()
        sys.exit(1)
