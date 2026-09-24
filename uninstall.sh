#!/bin/bash
# Stops the app, restores normal sleep, and removes its copy in ~/Applications and its sudoers line. Switch off "Launch at login" in its settings first, or remove the stale entry in System Settings > General > Login Items.
set -euo pipefail

APP=MacUtilities.app
EXECUTABLE=MacUtilities
APPS_DIR=$HOME/Applications
SUDOERS_FILE=/etc/sudoers.d/mac-utilities-pmset

pkill -x "$EXECUTABLE" || true
while pgrep -x "$EXECUTABLE" > /dev/null; do sleep 0.1; done
rm -rf "${APPS_DIR:?}/$APP"

sudo /usr/bin/pmset -a disablesleep 0
sudo rm -f "$SUDOERS_FILE"

echo "removed $APPS_DIR/$APP and $SUDOERS_FILE"
