# mac-utilities

Self-built macOS utilities, hosted as toggleable features of one menu bar app,
`MacUtilities.app`. The features share one event tap, one Accessibility grant and
one launchd agent. Swift Package, no Xcode project.

## Features

The menu bar item has a checkmark toggle per feature; a feature switched off stops
on the spot and stays off across launches. Below the toggles come each feature's own
menu entries, then Quit.

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

Builds the app, copies it to `~/Applications` and bootstraps the launch agent, so it
runs now and at login. `./uninstall.sh` stops it and removes both. The app asks for
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

Always launch with `install.sh`, launchd or `open MacUtilities.app`. Running the
binary directly from a terminal makes the terminal the responsible process for the
Accessibility permission, and the event tap fails.

## Setup

Run `./create-signing-cert.sh` once. It creates a self-signed "mac-utilities" certificate that `build.sh` signs with, so rebuilt apps keep their Accessibility permission. If a rebuilt app asks for permission again, run `tccutil reset Accessibility com.ulvifk.mac-utilities` and grant it once more.

## Layout

```
Sources/MacUtilities/
  main.swift          starts the app with the list of features
  Core/               the host: Feature protocol, AppController (menu bar item, feature
                      lifecycle), EventTap, key matching, Preferences, Accessibility trust
  Features/<Name>/    one folder per feature
docs/<name>/          the feature's README and screenshots
```

A feature implements `Feature`: a stable `identifier` (the key its enabled state is
stored under), a `displayName`, `start()`, `stop()`, `handle(type:event:) -> Bool`
and `buildMenuItems()`. The core tap hands every key press and modifier change to
the enabled features in order; the first one returning `true` swallows the event.
Enabled features are stored in UserDefaults under `enabledFeatures`, every feature
enabled until switched off. New features are registered in `main.swift`.
