#!/bin/bash
# Stops a utility, removes its launch agent and its copy in ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

UTILITY=$1
APPS_DIR=$HOME/Applications
AGENTS_DIR=$HOME/Library/LaunchAgents

for PLIST in "$UTILITY"/*.plist; do
    [ -e "$PLIST" ] || continue
    LABEL=$(basename "$PLIST" .plist)
    launchctl bootout "gui/$(id -u)/$LABEL" || true
    rm -f "$AGENTS_DIR/$(basename "$PLIST")"
done

APP_NAME=$(basename "$(ls -d "$UTILITY"/*.app)")
rm -rf "${APPS_DIR:?}/$APP_NAME"

echo "removed $APPS_DIR/$APP_NAME"
