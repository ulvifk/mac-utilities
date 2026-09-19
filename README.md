# mac-utilities

Self-built macOS utilities, one folder per tool. Native Swift apps built with Apple’s command-line tools.

## app-switcher

Replaces Cmd+Tab with a switcher that can be filtered to a whitelist of apps.

![all apps](app-switcher/screenshots/all-apps.png)

![filtered to the whitelist](app-switcher/screenshots/filtered.png)

## my-dock

An Apple-like glass Dock with a collapsible group of app icons. Drag apps between
the visible and hidden groups, reorder them, or move them through native menus.
MyDock owns its app list and stays visible throughout each drag.

![shown](my-dock/screenshots/shown.png)

![hidden](my-dock/screenshots/hidden.png)

## Install

```sh
./install.sh app-switcher
./install.sh my-dock
```

`install.sh <utility>` builds it, copies the app to `~/Applications` and bootstraps
its launch agent, so it runs now and at login. `uninstall.sh <utility>` stops it and
removes both. AppSwitcher needs Accessibility access. MyDock’s core features do not;
existing access enables optional badge counts. See [MyDock setup](my-dock/README.md)
for keeping Apple’s Dock out of the way and restoring its settings.

## Setup

Run `./create-signing-cert.sh` once. It creates a self-signed "mac-utilities" certificate that every `build.sh` signs with, so rebuilt apps keep their Accessibility permission. If a rebuilt app asks for permission again, run `tccutil reset Accessibility <bundle id>` and grant it once more.
