#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "▸ Building LuminaCut…"
swift build -c release 2>&1

BIN="$(swift build -c release --show-bin-path)/LuminaCut"
APP="$ROOT/dist/LuminaCut.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>LuminaCut</string>
  <key>CFBundleDisplayName</key><string>LuminaCut</string>
  <key>CFBundleIdentifier</key><string>ai.x.luminacut</string>
  <key>CFBundleVersion</key><string>1.0.0</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>LuminaCut</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.video</string>
</dict>
</plist>
PLIST

cp "$BIN" "$APP/Contents/MacOS/LuminaCut"
chmod +x "$APP/Contents/MacOS/LuminaCut"
echo "▸ Launching $APP"
open "$APP"
