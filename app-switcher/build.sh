#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swiftc -O -o app-switcher main.swift

APP=AppSwitcher.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp app-switcher "$APP/Contents/MacOS/app-switcher"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.ulvifk.app-switcher</string>
    <key>CFBundleExecutable</key>
    <string>app-switcher</string>
    <key>CFBundleName</key>
    <string>AppSwitcher</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

codesign -s mac-utilities --force "$APP"
echo "built $APP"
