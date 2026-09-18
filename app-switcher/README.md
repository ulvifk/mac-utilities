# app-switcher

Menu bar app that replaces Cmd+Tab with its own switcher. With "Filter enabled" on
the switcher only lists whitelisted apps; with it off it lists every running app.
While the app runs, the native Cmd+Tab switcher is never shown: if the filter is on
but no whitelisted app is running, the switcher lists every running app instead, so
the shortcuts below always stay reachable.

The menu bar item toggles the filter, lists the two in-switcher shortcuts as a
reminder, and manages the whitelist (every running regular app is listed,
checkmark = whitelisted).

## Switcher

- Cmd+Tab / Cmd+Shift+Tab cycle forward and backward; releasing Cmd activates the
  selection.
- Right / Left arrow do the same while the switcher is open.
- Click an icon to switch to it.
- The selected app's name sits under its icon, inside the highlight, clamped to the
  panel edges and truncated rather than ever widening the panel.
- The highlight is green when the filter is on and neutral when it is off.
- A small green dot above an icon means the app is whitelisted.
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

## Dev

Open the panel once without a keyboard, print its geometry, capture it to
`/tmp/app-switcher-smoke.png` and exit:

```sh
APP_SWITCHER_SMOKE_TEST=1 APP_SWITCHER_SMOKE_INDEX=3 APP_SWITCHER_SMOKE_FILTER=1 \
  ./AppSwitcher.app/Contents/MacOS/app-switcher
```

`APP_SWITCHER_SMOKE_INDEX` picks the selected app (default 1) and
`APP_SWITCHER_SMOKE_FILTER=1/0` writes the filter preference before showing the
panel. The capture is a screen-region capture of our own windows, so it needs no
Screen Recording permission but only shows the desktop and this app. A gradient
window is put behind the panel first, so the glass has something to blur.

## Run at login

```sh
cp com.ulvifk.app-switcher.plist ~/Library/LaunchAgents/ && launchctl load ~/Library/LaunchAgents/com.ulvifk.app-switcher.plist
```

Always launch with `open AppSwitcher.app` or launchd. Running the binary directly from a terminal makes the terminal the responsible process for the Accessibility permission, and the event tap fails.
