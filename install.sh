#!/bin/bash
# Builds the app, installs it into ~/Applications with the sudoers line Keep awake needs, and launches it.
set -euo pipefail
cd "$(dirname "$0")"

APP=MacUtilities.app
EXECUTABLE=MacUtilities
APPS_DIR=$HOME/Applications
SUDOERS_FILE=/etc/sudoers.d/mac-utilities-pmset

if ! security find-identity -v -p codesigning | grep -q mac-utilities; then
    ./create-signing-cert.sh
fi

# Keep awake runs `sudo -n /usr/bin/pmset -a disablesleep 0|1`; this lets the current user do exactly that and nothing else without a password.
SUDOERS_TMP=$(mktemp)
echo "$(id -un) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1" > "$SUDOERS_TMP"
visudo -c -f "$SUDOERS_TMP"
sudo install -m 0440 -o root -g wheel "$SUDOERS_TMP" "$SUDOERS_FILE"
rm -f "$SUDOERS_TMP"

./build.sh

mkdir -p "$APPS_DIR"
pkill -x "$EXECUTABLE" || true
while pgrep -x "$EXECUTABLE" > /dev/null; do sleep 0.1; done
rm -rf "${APPS_DIR:?}/$APP"
cp -R "$APP" "$APPS_DIR/$APP"
open "$APPS_DIR/$APP"

echo "installed $APPS_DIR/$APP and $SUDOERS_FILE"
echo "Grant Accessibility once in System Settings > Privacy & Security > Accessibility (first install only)."
echo "Switch on 'Launch at login' in the app's Settings > General to start it at login."
