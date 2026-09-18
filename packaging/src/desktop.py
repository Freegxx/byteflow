#!/usr/bin/env python3
"""ByteFlow desktop shell — native window (WKWebView), not system browser."""
from __future__ import annotations

import atexit
import os
import signal
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
DATA_DIR = Path(os.environ.get("BYTEFLOW_DATA_DIR") or
                (Path.home() / "Library" / "Application Support" / "ByteFlow"))
DATA_DIR.mkdir(parents=True, exist_ok=True)
(LOG_DIR := DATA_DIR / "logs").mkdir(exist_ok=True)
(PID_DIR := DATA_DIR / ".pids").mkdir(exist_ok=True)

URL = "http://127.0.0.1:8787"
PROCS: list[subprocess.Popen] = []


def _pidfile(name: str) -> Path:
    return PID_DIR / f"{name}.pid"


def _kill_old(name: str) -> None:
    pf = _pidfile(name)
    if pf.exists():
        try:
            os.kill(int(pf.read_text().strip()), signal.SIGTERM)
        except Exception:
            pass
        pf.unlink(missing_ok=True)


def _start(name: str, script: str) -> None:
    _kill_old(name)
    log = open(LOG_DIR / f"{name}.log", "a", buffering=1)
    p = subprocess.Popen(
        [sys.executable, "-u", str(APP_DIR / script)],
        cwd=str(APP_DIR),
        stdout=log,
        stderr=subprocess.STDOUT,
        start_new_session=True,
        env={**os.environ, "BYTEFLOW_DATA_DIR": str(DATA_DIR)},
    )
    _pidfile(name).write_text(str(p.pid))
    PROCS.append(p)


def _wait_api(timeout: float = 30.0) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(URL, timeout=1) as r:
                if r.status == 200:
                    return
        except Exception:
            time.sleep(0.25)
    raise RuntimeError("ByteFlow API 未能在时限内启动: " + URL)


def shutdown() -> None:
    for name in ("menubar", "api", "collector"):
        _kill_old(name)
    for p in PROCS:
        try:
            p.terminate()
        except Exception:
            pass


def main() -> int:
    atexit.register(shutdown)
    # DB convenience symlink for older code paths
    db_link = APP_DIR / "byteflow.db"
    if not db_link.exists():
        try:
            db_link.symlink_to(DATA_DIR / "byteflow.db")
        except Exception:
            pass

    _start("collector", "collector.py")
    _start("api", "api.py")
    _wait_api()

    try:
        import webview
    except ImportError:
        print("缺少 pywebview，无法打开原生窗口", file=sys.stderr)
        return 1

    window = webview.create_window(
        "ByteFlow — 网络流量监控",
        URL,
        width=1280,
        height=840,
        min_size=(900, 600),
        confirm_close=True,
    )

    def _on_closing():
        shutdown()

    try:
        window.events.closing += lambda: shutdown()
    except Exception:
        pass

    webview.start()
    shutdown()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
