#!/bin/bash
# Builds the app, installs it into ~/Applications and starts it through launchd.
set -euo pipefail
cd "$(dirname "$0")"

APP=MacUtilities.app
EXECUTABLE=MacUtilities
LABEL=com.ulvifk.mac-utilities
APPS_DIR=$HOME/Applications
AGENTS_DIR=$HOME/Library/LaunchAgents

if ! security find-identity -v -p codesigning | grep -q mac-utilities; then
    ./create-signing-cert.sh
fi

./build.sh

mkdir -p "$APPS_DIR"
pkill -x "$EXECUTABLE" || true
rm -rf "${APPS_DIR:?}/$APP"
cp -R "$APP" "$APPS_DIR/$APP"

mkdir -p "$AGENTS_DIR"
cp "$LABEL.plist" "$AGENTS_DIR/"
launchctl bootout "gui/$(id -u)/$LABEL" || true
launchctl bootstrap "gui/$(id -u)" "$AGENTS_DIR/$LABEL.plist"

echo "installed $APPS_DIR/$APP"
echo "Grant Accessibility once in System Settings > Privacy & Security > Accessibility (first install only)."
