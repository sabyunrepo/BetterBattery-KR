#!/bin/bash
# Renders the SVG icon with tools already included in macOS and CI runners.
set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET="build/AppIcon.iconset"
mkdir -p "$ICONSET"
sips -s format png docs/app-icon.svg --out "$ICONSET/icon_512x512@2x.png" >/dev/null

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ICONSET/icon_512x512@2x.png" \
    --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  if [ "$size" -lt 512 ]; then
    doubled=$((size * 2))
    sips -z "$doubled" "$doubled" "$ICONSET/icon_512x512@2x.png" \
      --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  fi
done

iconutil -c icns "$ICONSET" -o Support/AppIcon.icns
echo "Wrote Support/AppIcon.icns"
