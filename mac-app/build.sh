#!/bin/sh
# Builds "Claude Sessions Dashboard.app" in build/ with server.py, index.html and demo/ bundled.
set -e
cd "$(dirname "$0")/.."
APP="build/Claude Sessions Dashboard.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/server"
cp mac-app/Info.plist "$APP/Contents/"
cp server.py index.html "$APP/Contents/Resources/server/"
cp -R demo "$APP/Contents/Resources/server/"
# App icon: mac-app/icon.png (drawn by make-icon.swift) -> AppIcon.icns
ICONSET="$(mktemp -d)/AppIcon.iconset"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s mac-app/icon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) mac-app/icon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
swiftc -O -o "$APP/Contents/MacOS/ClaudeSessionsDashboard" mac-app/main.swift
codesign --force --sign - "$APP"
echo "Built $APP"
