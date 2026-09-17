# app-switcher

Menu bar app that replaces Cmd+Tab with a switcher limited to a whitelist of apps.
When "Filter enabled" is off, the native Cmd+Tab behaves as usual; the same happens
when no whitelisted app is running.

The menu bar item toggles the filter and manages the whitelist (every running
regular app is listed, checkmark = whitelisted).

## Build

```sh
./build.sh
open AppSwitcher.app
```

`build.sh` compiles `main.swift`, wraps the binary into `AppSwitcher.app` and
ad-hoc codesigns it (`codesign -s - --force AppSwitcher.app`), so macOS keeps the
granted Accessibility permission stable across rebuilds.

## Permissions

Grant Accessibility to `AppSwitcher.app` in
System Settings > Privacy & Security > Accessibility, then relaunch it.
Without it the event tap cannot be created and Cmd+Tab stays native.

## Run at login

```sh
cp com.ulvifk.app-switcher.plist ~/Library/LaunchAgents/ && launchctl load ~/Library/LaunchAgents/com.ulvifk.app-switcher.plist
```
