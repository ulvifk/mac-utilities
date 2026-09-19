# mac-utilities

Self-built macOS utilities, one folder per tool.

- `app-switcher/` — menu bar app replacing Cmd+Tab with a whitelist-filtered switcher.
- `my-dock/` — floating strip that replicates the macOS Dock one-to-one, fed by the real Dock's item list.

## Install

```sh
./install.sh app-switcher
./uninstall.sh app-switcher
```

`install.sh <utility>` builds it, copies the app to `~/Applications` and bootstraps
its launch agent, so it runs now and at login. `uninstall.sh <utility>` stops it and
removes both.

## Setup

Run `./create-signing-cert.sh` once. It creates a self-signed "mac-utilities" certificate that every `build.sh` signs with, so rebuilt apps keep their Accessibility permission. If a rebuilt app asks for permission again, run `tccutil reset Accessibility <bundle id>` and grant it once more.
