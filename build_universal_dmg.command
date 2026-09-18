#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT/packaging"
chmod +x build_universal_dmg.command
OUT="${1:-$ROOT/ByteFlow-universal.dmg}"
./build_universal_dmg.command "$OUT"
if [[ ! -f "$ROOT/ByteFlow-universal.dmg" && -f "$OUT" ]]; then cp "$OUT" "$ROOT/ByteFlow-universal.dmg"; fi
if [[ ! -f "$ROOT/ByteFlow-universal.dmg" && -f "$HOME/Desktop/ByteFlow-universal.dmg" ]]; then cp "$HOME/Desktop/ByteFlow-universal.dmg" "$ROOT/ByteFlow-universal.dmg"; fi
ls -lh "$ROOT/ByteFlow-universal.dmg"
