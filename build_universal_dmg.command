#!/bin/bash
# Root-level wrapper for packaging/build_universal_dmg.command
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$ROOT/ByteFlow-universal.dmg}"
chmod +x "$ROOT/packaging/build_universal_dmg.command"
exec "$ROOT/packaging/build_universal_dmg.command" "$OUT"
