#!/bin/bash
# Builds a utility, installs it into ~/Applications and starts it through launchd.
set -euo pipefail
cd "$(dirname "$0")"

UTILITY=$1
APPS_DIR=$HOME/Applications
AGENTS_DIR=$HOME/Library/LaunchAgents

if ! security find-identity -v -p codesigning | grep -q mac-utilities; then
    ./create-signing-cert.sh
fi

"$UTILITY/build.sh"

APP=$(ls -d "$UTILITY"/*.app)
APP_NAME=$(basename "$APP")
EXECUTABLE=$(basename "$APP/Contents/MacOS/"*)

mkdir -p "$APPS_DIR"
pkill -x "$EXECUTABLE" || true
rm -rf "${APPS_DIR:?}/$APP_NAME"
cp -R "$APP" "$APPS_DIR/$APP_NAME"

for PLIST in "$UTILITY"/*.plist; do
    [ -e "$PLIST" ] || continue
    LABEL=$(basename "$PLIST" .plist)
    mkdir -p "$AGENTS_DIR"
    cp "$PLIST" "$AGENTS_DIR/"
    launchctl bootout "gui/$(id -u)/$LABEL" || true
    launchctl bootstrap "gui/$(id -u)" "$AGENTS_DIR/$(basename "$PLIST")"
done

echo "installed $APPS_DIR/$APP_NAME"
if [ "$UTILITY" = my-dock ]; then
    echo "Core Dock features need no Accessibility permission. Existing access enables badge counts."
else
    echo "Grant Accessibility once in System Settings > Privacy & Security > Accessibility (first install only)."
fi
