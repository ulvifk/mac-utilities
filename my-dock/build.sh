#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swiftc -O -warnings-as-errors -o my-dock Sources/Model/*.swift Sources/Application/*.swift Sources/Platform/*.swift Sources/Presentation/*.swift main.swift

APP=MyDock.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp my-dock "$APP/Contents/MacOS/my-dock"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.ulvifk.my-dock</string>
    <key>CFBundleExecutable</key>
    <string>my-dock</string>
    <key>CFBundleName</key>
    <string>MyDock</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

codesign -s mac-utilities --force "$APP"
echo "built $APP"
