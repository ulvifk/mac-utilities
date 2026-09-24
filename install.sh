#!/bin/bash
# Builds the app, installs it into ~/Applications and launches it.
set -euo pipefail
cd "$(dirname "$0")"

APP=MacUtilities.app
EXECUTABLE=MacUtilities
APPS_DIR=$HOME/Applications

if ! security find-identity -v -p codesigning | grep -q mac-utilities; then
    ./create-signing-cert.sh
fi

./build.sh

mkdir -p "$APPS_DIR"
pkill -x "$EXECUTABLE" || true
while pgrep -x "$EXECUTABLE" > /dev/null; do sleep 0.1; done
rm -rf "${APPS_DIR:?}/$APP"
cp -R "$APP" "$APPS_DIR/$APP"
open "$APPS_DIR/$APP"

echo "installed $APPS_DIR/$APP"
echo "Grant Accessibility once in System Settings > Privacy & Security > Accessibility (first install only)."
echo "Switch on 'Launch at login' in the app's Settings > General to start it at login."
