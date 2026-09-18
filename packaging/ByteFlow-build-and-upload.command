#!/bin/bash
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
PROJECT="/Users/guxx/Developer/Personal/byteflow"
DESKTOP_DMG="$HOME/Desktop/ByteFlow-universal.dmg"
TAG="v1.2.0"
LOG="$HOME/Desktop/ByteFlow-build.log"
exec > >(tee "$LOG") 2>&1
echo "==== $(date) ===="
osascript -e 'display notification "开始打包…" with title "ByteFlow"' || true
mkdir -p "$PROJECT"
cd "$PROJECT"
[[ -f ByteFlow-universal-kit.tgz ]] || { echo "缺少 ByteFlow-universal-kit.tgz"; exit 1; }
rm -rf ByteFlow-universal-kit
tar xzf ByteFlow-universal-kit.tgz
cd ByteFlow-universal-kit
if [[ "$(uname -m)" == "arm64" ]] && ! arch -x86_64 /usr/bin/true 2>/dev/null; then
  softwareupdate --install-rosetta --agree-to-license || true
fi
chmod +x build_universal_dmg.command
./build_universal_dmg.command "$DESKTOP_DMG"
cp -f "$DESKTOP_DMG" "$PROJECT/ByteFlow-universal.dmg"
echo "本地: $PROJECT/ByteFlow-universal.dmg"
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  NOTES="ByteFlow Universal (arm64+x86_64) 自包含；原生窗口；拖到 Applications 即可。"
  if gh release view "$TAG" --repo Freegxx/byteflow >/dev/null 2>&1; then
    gh release upload "$TAG" "$DESKTOP_DMG" --repo Freegxx/byteflow --clobber
  else
    gh release create "$TAG" "$DESKTOP_DMG" --repo Freegxx/byteflow --title "ByteFlow $TAG" --notes "$NOTES"
  fi
  open "https://github.com/Freegxx/byteflow/releases/tag/$TAG" || true
else
  echo "gh 未就绪，跳过上传。请: brew install gh && gh auth login 后重跑上传。"
fi
open -R "$DESKTOP_DMG" || true
read -n 1 -s -r -p "完成，按任意键关闭…"
