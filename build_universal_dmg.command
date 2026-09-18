#!/bin/bash
# Root-level wrapper for packaging/build_universal_dmg.command
set -e
cd "$(dirname "$0")/packaging"
exec ./build_universal_dmg.command "$@"
