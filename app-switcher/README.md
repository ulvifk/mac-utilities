# app-switcher

Menu bar app that replaces Cmd+Tab with its own switcher. With "Filter enabled" on
the switcher only lists whitelisted apps; with it off it lists every running app.
Native Cmd+Tab is used only when there is nothing to show.

The menu bar item toggles the filter and manages the whitelist (every running
regular app is listed, checkmark = whitelisted).

## Switcher

- Cmd+Tab / Cmd+Shift+Tab cycle forward and backward; releasing Cmd activates the
  selection.
- The header shows whether the filter is ON or OFF.
- A green checkmark badge on an icon means the app is whitelisted.
- Cmd+W while the switcher is open toggles the whitelist membership of the selected
  app. The visible list is not re-filtered until the switcher closes.

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
