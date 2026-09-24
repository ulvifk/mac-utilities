#!/bin/bash
# Stops the app and removes its copy in ~/Applications. Switch off "Launch at login" in its settings first, or remove the stale entry in System Settings > General > Login Items.
set -euo pipefail

APP=MacUtilities.app
EXECUTABLE=MacUtilities
APPS_DIR=$HOME/Applications

pkill -x "$EXECUTABLE" || true
rm -rf "${APPS_DIR:?}/$APP"

echo "removed $APPS_DIR/$APP"
