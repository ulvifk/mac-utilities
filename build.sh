#!/bin/bash
# Builds the package and wraps the binary into MacUtilities.app, signed with the "mac-utilities" certificate.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=MacUtilities.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/MacUtilities "$APP/Contents/MacOS/MacUtilities"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.ulvifk.mac-utilities</string>
    <key>CFBundleExecutable</key>
    <string>MacUtilities</string>
    <key>CFBundleName</key>
    <string>MacUtilities</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

codesign -s mac-utilities --force "$APP"
echo "built $APP"
