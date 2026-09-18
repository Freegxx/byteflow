#!/bin/bash
# 生成 arm64+x86_64 合一的自包含 ByteFlow-universal.dmg（原生窗口，不依赖系统 pip）
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"
SRC="$ROOT/src"
WORK="$ROOT/_build"
APP="$WORK/ByteFlow.app"
OUT_DMG="${1:-$HOME/Desktop/ByteFlow-universal.dmg}"
# 同时写入项目目录（若存在）
PROJECT_DIR="/Users/guxx/Developer/Personal/byteflow"
PY_VERSION="3.12.14"
PBS_TAG="20260901"

echo "======================================"
echo " ByteFlow Universal DMG (arm64+x86_64)"
echo "======================================"
[[ "$(uname)" == "Darwin" ]] || { echo "请在 macOS 上运行"; exit 1; }

rm -rf "$WORK"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/app" \
  "$APP/Contents/Frameworks/python-arm64" "$APP/Contents/Frameworks/python-x86_64" \
  "$WORK/cache"

download_py() {
  local arch="$1" dest="$2"
  local pbs_arch name url
  case "$arch" in
    arm64) pbs_arch="aarch64" ;;
    x86_64) pbs_arch="x86_64" ;;
  esac
  name="cpython-${PY_VERSION}+${PBS_TAG}-${pbs_arch}-apple-darwin-install_only.tar.gz"
  url="https://github.com/astral-sh/python-build-standalone/releases/download/${PBS_TAG}/${name}"
  echo "下载 Python ${PY_VERSION} (${arch})..."
  [[ -f "$WORK/cache/$name" ]] || curl -L --fail --progress-bar -o "$WORK/cache/$name" "$url"
  mkdir -p "$dest"
  tar -C "$dest" -xzf "$WORK/cache/$name"
}

find_py() {
  # Prefer real interpreter, never *-config
  local cand
  for cand in "$1"/python/bin/python3 "$1"/python/bin/python3.12 "$1"/bin/python3; do
    if [[ -x "$cand" && ! "$cand" =~ config$ ]]; then
      echo "$cand"
      return 0
    fi
  done
  find "$1" -type f -path '*/bin/python3*' ! -name '*-config' | head -1
}

install_deps() {
  local py="$1"
  echo "  pip install → $py"
  "$py" -m ensurepip --upgrade >/dev/null 2>&1 || true
  "$py" -m pip install -U pip setuptools wheel >/dev/null
  "$py" -m pip install -r "$SRC/requirements-portable.txt"
  "$py" -c "import fastapi,uvicorn,aiosqlite,webview; print('  ok', __import__('sys').version)"
}

echo "1/6 下载双架构内置 Python..."
download_py arm64  "$APP/Contents/Frameworks/python-arm64"
download_py x86_64 "$APP/Contents/Frameworks/python-x86_64"
PY_ARM="$(find_py "$APP/Contents/Frameworks/python-arm64")"
PY_X86="$(find_py "$APP/Contents/Frameworks/python-x86_64")"
[[ -x "$PY_ARM" && -x "$PY_X86" ]] || { echo "Python 解压失败"; exit 1; }

# 在当前机器上只能原生跑本架构 pip；另一架构用 --platform 装纯 wheel 往往不够（含原生扩展）。
# 策略：本架构完整安装；另一架构若无法执行，则提示用 Rosetta/CI。若在 arm64 上，尝试 arch -x86_64。
echo "2/6 为双架构安装依赖..."
HOST="$(uname -m)"
install_deps "$PY_ARM"
if [[ "$HOST" == "arm64" ]]; then
  if arch -x86_64 /usr/bin/true 2>/dev/null; then
    echo "  通过 Rosetta 安装 x86_64 依赖..."
    arch -x86_64 "$PY_X86" -m ensurepip --upgrade >/dev/null 2>&1 || true
    arch -x86_64 "$PY_X86" -m pip install -U pip setuptools wheel
    arch -x86_64 "$PY_X86" -m pip install -r "$SRC/requirements-portable.txt"
    arch -x86_64 "$PY_X86" -c "import fastapi,webview; print('  x86 ok')"
  else
    echo "⚠ 未启用 Rosetta，x86_64 依赖可能不完整。建议: softwareupdate --install-rosetta"
    # 仍尝试直接调用（在 Intel 机器上 PY_X86 可跑；在 arm 无 Rosetta 会失败）
    install_deps "$PY_X86" || echo "⚠ x86_64 pip 失败，Intel Mac 上请用 CI 产物"
  fi
else
  install_deps "$PY_X86"
  echo "⚠ 当前为 Intel 机，arm64 依赖需在 Apple Silicon 或 CI 上补齐"
  install_deps "$PY_ARM" || true
fi

echo "3/6 复制应用代码..."
tar -C "$SRC" --exclude=venv --exclude='*.db' --exclude=logs --exclude=__pycache__ -cf - . \
  | tar -C "$APP/Contents/Resources/app" -xf -

echo "4/6 写入 Universal 启动器（按芯片选 Python，原生窗口）..."
cat > "$APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>ByteFlow</string>
  <key>CFBundleDisplayName</key><string>ByteFlow</string>
  <key>CFBundleIdentifier</key><string>com.byteflow.app</string>
  <key>CFBundleVersion</key><string>1.2.0</string>
  <key>CFBundleShortVersionString</key><string>1.2.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>ByteFlow</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppTransportSecurity</key>
  <dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict>
</plist>
PLIST

cat > "$APP/Contents/MacOS/ByteFlow" << 'LAUNCH'
#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_HOME="$ROOT/Resources/app"
ARCH="$(uname -m)"
case "$ARCH" in
  arm64) PY_ROOT="$ROOT/Frameworks/python-arm64" ;;
  x86_64) PY_ROOT="$ROOT/Frameworks/python-x86_64" ;;
  *) osascript -e "display alert \"不支持的架构: $ARCH\""; exit 1 ;;
esac
PY=""
for cand in "$PY_ROOT"/python/bin/python3 "$PY_ROOT"/python/bin/python3.12; do
  [[ -x "$cand" ]] && PY="$cand" && break
done
[[ -n "$PY" ]] || PY="$(find "$PY_ROOT" -type f -path '*/bin/python3*' ! -name '*-config' | head -1)"
[[ -x "${PY:-}" ]] || { osascript -e 'display alert "缺少对应架构的内置 Python"'; exit 1; }

DATA="$HOME/Library/Application Support/ByteFlow"
mkdir -p "$DATA/logs" "$DATA/.pids"
export BYTEFLOW_DATA_DIR="$DATA"

FLAG="$DATA/.asked-login"
if [[ ! -f "$FLAG" ]]; then
  touch "$FLAG"
  ANS=$(osascript -e 'button returned of (display dialog "是否开机自动启动 ByteFlow？" buttons {"否","是"} default button "是" with title "ByteFlow")' || echo "否")
  if [[ "$ANS" == "是" ]]; then
    PLIST="$HOME/Library/LaunchAgents/com.byteflow.agent.plist"
    mkdir -p "$HOME/Library/LaunchAgents"
    cat > "$PLIST" << P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.byteflow.agent</string>
  <key>ProgramArguments</key>
  <array><string>$ROOT/MacOS/ByteFlow</string><string>--background</string></array>
  <key>RunAtLoad</key><true/>
  <key>WorkingDirectory</key><string>$DATA</string>
  <key>StandardOutPath</key><string>$DATA/logs/launchd.out.log</string>
  <key>StandardErrorPath</key><string>$DATA/logs/launchd.err.log</string>
</dict></plist>
P
    launchctl unload "$PLIST" 2>/dev/null || true
    launchctl load "$PLIST" 2>/dev/null || launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null || true
  fi
fi

cd "$APP_HOME"
if [[ "${1:-}" == "--background" ]]; then
  for n in api collector menubar; do
    [[ -f "$DATA/.pids/$n.pid" ]] && kill "$(cat "$DATA/.pids/$n.pid")" 2>/dev/null || true
  done
  nohup "$PY" -u collector.py >>"$DATA/logs/collector.log" 2>&1 & echo $! > "$DATA/.pids/collector.pid"
  nohup "$PY" -u api.py >>"$DATA/logs/api.log" 2>&1 & echo $! > "$DATA/.pids/api.pid"
  exit 0
fi

# 原生窗口，不打开浏览器
exec "$PY" -u desktop.py
LAUNCH
chmod +x "$APP/Contents/MacOS/ByteFlow"
xattr -cr "$APP" 2>/dev/null || true

echo "5/6 生成 DMG..."
STAGE="$WORK/dmgstage"
rm -rf "$STAGE" && mkdir -p "$STAGE"
ditto "$APP" "$STAGE/ByteFlow.app"
ln -sf /Applications "$STAGE/Applications"
cat > "$STAGE/安装说明.txt" << 'T'
ByteFlow Universal（Apple Silicon + Intel）
1. 拖 ByteFlow 到 Applications
2. 打开后为软件自带窗口（非浏览器）
3. 未公证时：右键 → 打开 → 仍要打开
数据目录：~/Library/Application Support/ByteFlow/
T

rm -f "$OUT_DMG" /tmp/byteflow-uni-rw.dmg
hdiutil create -volname "ByteFlow" -srcfolder "$STAGE" -ov -format UDRW /tmp/byteflow-uni-rw.dmg
hdiutil convert /tmp/byteflow-uni-rw.dmg -format UDZO -imagekey zlib-level=9 -o "$OUT_DMG"
rm -f /tmp/byteflow-uni-rw.dmg

echo "6/6 复制到项目目录（如存在）..."
if [[ -d "$PROJECT_DIR" ]]; then
  cp -f "$OUT_DMG" "$PROJECT_DIR/ByteFlow-universal.dmg"
  echo "  → $PROJECT_DIR/ByteFlow-universal.dmg"
fi
# 也放一份到套件目录旁
cp -f "$OUT_DMG" "$ROOT/ByteFlow-universal.dmg" 2>/dev/null || true

echo ""
echo "✓ Universal DMG: $OUT_DMG"
echo "上传到 GitHub Release 示例："
echo "  gh release create v1.2.0 \"$OUT_DMG\" --repo Freegxx/byteflow --title \"ByteFlow v1.2.0\" --notes \"Universal DMG (arm64+x86_64)\""
open -R "$OUT_DMG" 2>/dev/null || true
