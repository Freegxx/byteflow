#!/bin/bash
# ByteFlow macOS 安装脚本
set -e

INSTALL_DIR="$HOME/Applications/ByteFlow"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT_PLIST="com.byteflow.agent.plist"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "======================================"
echo "ByteFlow 安装向导"
echo "======================================"
echo ""

if [[ "$(uname)" != "Darwin" ]]; then
  echo "错误: 仅支持 macOS"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "错误: 未找到 Python 3"
  exit 1
fi

PY_VER=$(python3 -c 'import sys; print("%d.%d"%sys.version_info[:2])')
echo "✓ Python $PY_VER 已安装"

echo ""
echo "创建安装目录: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR/logs" "$INSTALL_DIR/web"

echo "复制应用文件..."
# 复制代码，保留已有数据库
rsync -a --exclude 'venv' --exclude '*.db' --exclude 'logs' --exclude '__pycache__' \
  --exclude '.git' "$SRC_DIR/" "$INSTALL_DIR/" || {
  # fallback without rsync
  for f in "$SRC_DIR"/*; do
    base=$(basename "$f")
    case "$base" in venv|*.db|logs|__pycache__|.git) continue ;; esac
    cp -R "$f" "$INSTALL_DIR/"
  done
}

cd "$INSTALL_DIR"

echo ""
echo "创建虚拟环境并安装依赖..."
if [[ ! -d venv ]]; then
  python3 -m venv venv
fi
# shellcheck disable=SC1091
source venv/bin/activate
python -m pip install -U pip setuptools wheel -q

# 核心依赖（不含菜单栏）
python -m pip install -q \
  "fastapi==0.115.0" \
  "uvicorn==0.30.6" \
  "python-multipart==0.0.12" \
  "aiosqlite==0.20.0"

MENUBAR_OK=0
echo "安装菜单栏依赖（可选）..."
if python -m pip install -q "pyobjc-core==10.3.2" "pyobjc-framework-Cocoa==10.3.2" "rumps==0.4.0"; then
  MENUBAR_OK=1
  echo "✓ 菜单栏组件已安装"
else
  echo "⚠ 菜单栏依赖安装失败，Web 版仍可正常使用（可稍后再装）"
fi

# 启动/停止脚本（用 venv python）
cat > "$INSTALL_DIR/start.sh" << 'S'
#!/bin/bash
cd "$(dirname "$0")"
# shellcheck disable=SC1091
source venv/bin/activate
mkdir -p logs .pids
./stop.sh >/dev/null 2>&1 || true
nohup python -u collector.py >> logs/collector.log 2>&1 & echo $! > .pids/collector.pid
nohup python -u api.py >> logs/api.log 2>&1 & echo $! > .pids/api.pid
if [[ -f menubar.py ]] && python -c "import rumps" 2>/dev/null; then
  nohup python -u menubar.py >> logs/menubar.log 2>&1 & echo $! > .pids/menubar.pid
fi
sleep 1
echo "ByteFlow 已后台启动: http://127.0.0.1:8787"
S
chmod +x "$INSTALL_DIR/start.sh"

cat > "$INSTALL_DIR/stop.sh" << 'S'
#!/bin/bash
cd "$(dirname "$0")"
for f in .pids/collector.pid .pids/api.pid .pids/menubar.pid; do
  if [[ -f "$f" ]]; then
    kill "$(cat "$f")" 2>/dev/null || true
    rm -f "$f"
  fi
done
pkill -f "$PWD/collector.py" 2>/dev/null || true
pkill -f "$PWD/api.py" 2>/dev/null || true
pkill -f "$PWD/menubar.py" 2>/dev/null || true
echo "ByteFlow 已停止"
S
chmod +x "$INSTALL_DIR/stop.sh"

# LaunchAgent
mkdir -p "$LAUNCH_AGENT_DIR"
PLIST_PATH="$LAUNCH_AGENT_DIR/$LAUNCH_AGENT_PLIST"
cat > "$PLIST_PATH" << P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.byteflow.agent</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$INSTALL_DIR/start.sh</string>
  </array>
  <key>RunAtLoad</key>
  <false/>
  <key>WorkingDirectory</key>
  <string>$INSTALL_DIR</string>
  <key>StandardOutPath</key>
  <string>$INSTALL_DIR/logs/launchd.out.log</string>
  <key>StandardErrorPath</key>
  <string>$INSTALL_DIR/logs/launchd.err.log</string>
</dict>
</plist>
P

echo ""
echo "是否开机自动启动 ByteFlow? (y/N)"
read -r ANSWER || ANSWER="n"
if [[ "$ANSWER" == "y" || "$ANSWER" == "Y" ]]; then
  /usr/libexec/PlistBuddy -c "Set :RunAtLoad true" "$PLIST_PATH" 2>/dev/null || \
    sed -i '' 's/<key>RunAtLoad<\/key>.*/<key>RunAtLoad<\/key><true\/>/' "$PLIST_PATH" 2>/dev/null || true
  # rewrite RunAtLoad true simply
  cat > "$PLIST_PATH" << P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.byteflow.agent</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$INSTALL_DIR/start.sh</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>WorkingDirectory</key>
  <string>$INSTALL_DIR</string>
  <key>StandardOutPath</key>
  <string>$INSTALL_DIR/logs/launchd.out.log</string>
  <key>StandardErrorPath</key>
  <string>$INSTALL_DIR/logs/launchd.err.log</string>
</dict>
</plist>
P
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  launchctl load "$PLIST_PATH" 2>/dev/null || launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || true
  echo "✓ 已开启开机自启"
else
  echo "已跳过开机自启（以后可再 load LaunchAgent）"
fi

echo ""
echo "启动 ByteFlow..."
"$INSTALL_DIR/start.sh" || true
sleep 2

echo ""
echo "======================================"
echo "✓ 安装完成"
echo "======================================"
echo "目录: $INSTALL_DIR"
echo "网页: http://127.0.0.1:8787"
if [[ "$MENUBAR_OK" -eq 1 ]]; then
  echo "菜单栏: 已随 start.sh 启动"
else
  echo "菜单栏: 未安装（不影响网页监控）"
fi
echo "停止: $INSTALL_DIR/stop.sh"
echo ""
open "http://127.0.0.1:8787" 2>/dev/null || true
