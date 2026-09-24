# mac-utilities

Self-built macOS utilities, hosted as toggleable features of one menu bar app,
`MacUtilities.app`. The features share one event tap, one Accessibility grant and
one login item. Swift Package, no Xcode project.

## Menu bar item and settings

The menu bar item has three entries: Paused, which lets every key press through
untouched until it is unchecked; Settings..., which opens the settings window; and
Quit.

The settings window has a General tab and one tab per feature. General holds a
switch per feature (a feature switched off stops on the spot and stays off across
launches), a "Launch at login" switch and an Accessibility row with a green or red
dot and a button to the Privacy & Security > Accessibility pane; the dot is
re-checked whenever the window comes back to the front. Every change applies
immediately.

## Features

### app-switcher

Replaces Cmd+Tab with a switcher that can be filtered to a whitelist of apps.
See [docs/app-switcher](docs/app-switcher/README.md) for the shortcuts and the
smoke test.

![all apps](docs/app-switcher/screenshots/all-apps.png)

![filtered to the whitelist](docs/app-switcher/screenshots/filtered.png)

## Install

```sh
./install.sh
```

Builds the app, copies it to `~/Applications` and launches it. Switch on "Launch at
login" in Settings > General to have it start at login; that registers the app as a
login item through `SMAppService`, listed under System Settings > General > Login
Items. `./uninstall.sh` stops the app and removes the copy; switch the login item
off first, or remove the stale entry from Login Items afterwards. The app asks for
Accessibility once on first launch.

## Build

For development, without installing:

```sh
./build.sh
open MacUtilities.app
```

`build.sh` runs `swift build -c release`, wraps the binary into `MacUtilities.app`
and signs it with the "mac-utilities" certificate, so macOS keeps the granted
Accessibility permission stable across rebuilds.

Always launch with `install.sh`, the login item or `open MacUtilities.app`. Running
the binary directly from a terminal makes the terminal the responsible process for
the Accessibility permission, and the event tap fails.

To check the settings window without installing, open it once, capture every tab to
`/tmp/settings-<tab>-smoke.png` and exit:

```sh
SETTINGS_SMOKE_TEST=1 ./MacUtilities.app/Contents/MacOS/MacUtilities
```

## Setup

Run `./create-signing-cert.sh` once. It creates a self-signed "mac-utilities" certificate that `build.sh` signs with, so rebuilt apps keep their Accessibility permission. If a rebuilt app asks for permission again, run `tccutil reset Accessibility com.ulvifk.mac-utilities` and grant it once more.

## Layout

```
Sources/MacUtilities/
  main.swift          starts the app with the list of features
  Core/               the host: Feature protocol, AppController (menu bar item, feature
                      lifecycle, pause), EventTap, key matching, Preferences,
                      Accessibility trust, window capture for the smoke tests
  Settings/           the settings window, its General tab and the settings smoke test
  Features/<Name>/    one folder per feature
docs/<name>/          the feature's README and screenshots
```

A feature implements `Feature`: a stable `identifier` (the key its enabled state is
stored under), a `displayName`, `start()`, `stop()`, `handle(type:event:) -> Bool`
and `buildSettingsView() -> AnyView`, its tab in the settings window. The core tap
hands every key press and modifier change to the enabled features in order; the
first one returning `true` swallows the event.
Switched-off features are stored in UserDefaults under `disabledFeatures`, so a
feature runs until it is switched off, new ones included. New features are
registered in `main.swift`.
