#!/bin/bash
# Move Apple's Dock away from MyDock; restore only the two changed settings.
set -euo pipefail
BACKUP="$HOME/Library/Application Support/MyDock/apple-dock-before-mydock.plist"
case "${1:-}" in
    enable)
        mkdir -p "$(dirname "$BACKUP")"
        if [ ! -f "$BACKUP" ]; then
            defaults export com.apple.dock "$BACKUP"
        fi
        defaults write com.apple.dock autohide -bool true
        defaults write com.apple.dock orientation -string left
        ;;
    restore)
        if [ ! -f "$BACKUP" ]; then
            echo "No saved Apple Dock settings." >&2
            exit 1
        fi
        for KEY in autohide orientation; do
            if VALUE=$(/usr/libexec/PlistBuddy -c "Print :$KEY" "$BACKUP" 2>/dev/null); then
                if [ "$KEY" = autohide ]; then
                    defaults write com.apple.dock "$KEY" -bool "$VALUE"
                else
                    defaults write com.apple.dock "$KEY" -string "$VALUE"
                fi
            elif defaults read com.apple.dock "$KEY" >/dev/null 2>&1; then
                defaults delete com.apple.dock "$KEY"
            fi
        done
        ;;
    *)
        echo "Usage: $0 enable|restore" >&2
        exit 1
        ;;
esac
killall Dock
