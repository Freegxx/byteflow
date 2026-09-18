#!/bin/bash
# Create ByteFlow app icon
# Generates a simple icon using sips (macOS built-in tool)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICON_DIR="$SCRIPT_DIR/icon"
mkdir -p "$ICON_DIR"

# Create base PNG using ImageMagick or sips fallback
# For now, create a placeholder icon file reference
echo "Creating ByteFlow icon..."

# Icon will be created manually or using design tools
# Placeholder: create icon.iconset structure

mkdir -p "$ICON_DIR/icon.iconset"

# Required icon sizes for macOS
# icon_16x16.png
# icon_32x32.png  
# icon_64x64.png
# icon_128x128.png
# icon_256x256.png
# icon_512x512.png
# icon_1024x1024.png

echo "Icon placeholder created at $ICON_DIR"
echo "To generate .icns:"
echo "  1. Place icon files in $ICON_DIR/icon.iconset/"
echo "  2. Run: iconutil -c icns $ICON_DIR/icon.iconset -o $ICON_DIR/icon.icns"
