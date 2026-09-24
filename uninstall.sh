#!/bin/bash
# Stops the app, removes its launch agent and its copy in ~/Applications.
set -euo pipefail

APP=MacUtilities.app
LABEL=com.ulvifk.mac-utilities
APPS_DIR=$HOME/Applications
AGENTS_DIR=$HOME/Library/LaunchAgents

launchctl bootout "gui/$(id -u)/$LABEL" || true
rm -f "$AGENTS_DIR/$LABEL.plist"
rm -rf "${APPS_DIR:?}/$APP"

echo "removed $APPS_DIR/$APP"
