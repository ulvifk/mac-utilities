# app-switcher

Menu bar app that replaces Cmd+Tab with its own switcher. With "Filter enabled" on
the switcher only lists whitelisted apps; with it off it lists every running app.
While the app runs, the native Cmd+Tab switcher is never shown: if the filter is on
but no whitelisted app is running, the switcher lists every running app instead, so
the shortcuts below always stay reachable.

The menu bar item toggles the filter, quits every app not in the whitelist,
lists the in-switcher shortcuts as a reminder, and manages the whitelist (every
running regular app is listed, checkmark = whitelisted).

Filter off, every running app listed:

![all apps](screenshots/all-apps.png)

Filter on, only the whitelist, green highlight:

![filtered](screenshots/filtered.png)

## Switcher

- Cmd+Tab / Cmd+Shift+Tab cycle forward and backward; releasing Cmd activates the
  selection.
- Right / Left arrow do the same while the switcher is open.
- Up / Down arrow move the selection one row up or down, keeping the same column;
  when the target row is shorter, the selection lands on its last icon.
- Click an icon to switch to it.
- Apps without open windows are left out.
- Hidden apps stay listed with a dimmed icon, whether they were hidden with Cmd+H here
  or anywhere else; releasing Cmd on one unhides and activates it.
- The highlight is a rounded square hugging the selected icon; the app's name sits
  under it, clamped to the panel edges and truncated rather than ever widening the
  panel.
- The highlight is green when the filter is on and neutral when it is off.
- A small green dot above an icon means the app is whitelisted.
- Cmd+F while the switcher is open toggles the filter itself and re-filters the list
  on the spot, keeping the selected app selected when it survives.
- Cmd+W while the switcher is open toggles the whitelist membership of the selected
  app. The visible list is not re-filtered until the switcher closes.
- Cmd+Q while the switcher is open quits the selected app; it leaves the list once it
  has actually quit, so an app asking for confirmation stays listed. Its icon fades and
  shrinks out while the others slide together and the panel shrinks around them; the
  highlight stays on the same app, or moves to a neighbour when that was the one quit.
- Cmd+X while the switcher is open quits every running app not in the whitelist, the
  same as the menu bar item. Each app gets a normal quit, so one with unsaved changes
  shows its dialog and stays running; the others leave the list as they quit.
- Cmd+H while the switcher is open hides the selected app; it stays listed, dimmed, and
  a second press does nothing.
- Esc closes the switcher without activating anything.

## Install

```sh
../install.sh app-switcher
```

Builds, copies the app to `~/Applications` and starts it through launchd, so it
also runs at login. `../uninstall.sh app-switcher` reverses it.

## Build

For development, without installing:

```sh
./build.sh
open AppSwitcher.app
```

`build.sh` compiles `main.swift`, wraps the binary into `AppSwitcher.app` and
signs it with the "mac-utilities" certificate, so macOS keeps the granted
Accessibility permission stable across rebuilds.

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

`APP_SWITCHER_SMOKE_INDEX` picks the selected app (default 1),
`APP_SWITCHER_SMOKE_FILTER=1/0` writes the filter preference before showing the
panel and `APP_SWITCHER_SMOKE_DARK=1` swaps the gradient behind the panel for a
dark one. The capture is a screen-region capture of our own windows, so it needs no
Screen Recording permission but only shows the desktop and this app. A gradient
window is put behind the panel first, so the glass has something to blur.

Always launch with `install.sh`, launchd or `open AppSwitcher.app`. Running the
binary directly from a terminal makes the terminal the responsible process for the
Accessibility permission, and the event tap fails.
