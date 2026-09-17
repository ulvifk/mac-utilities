# app-switcher

Menu bar app that replaces Cmd+Tab with its own switcher. With "Filter enabled" on
the switcher only lists whitelisted apps; with it off it lists every running app.
While the app runs, the native Cmd+Tab switcher is never shown: if the filter is on
but no whitelisted app is running, the switcher lists every running app instead and
its header says so, so the shortcuts below always stay reachable.

The menu bar item toggles the filter and manages the whitelist (every running
regular app is listed, checkmark = whitelisted).

## Switcher

- Cmd+Tab / Cmd+Shift+Tab cycle forward and backward; releasing Cmd activates the
  selection.
- Right / Left arrow do the same while the switcher is open.
- The header shows whether the filter is ON or OFF, and whether it fell back to
  listing everything because no whitelisted app is running.
- A green checkmark badge on an icon means the app is whitelisted.
- Cmd+F while the switcher is open toggles the filter itself and re-filters the list
  on the spot, keeping the selected app selected when it survives.
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
