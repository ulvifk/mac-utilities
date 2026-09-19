# my-dock

Menu bar app that replaces the macOS 27 Dock with a strip replicating it one-to-one:
same glass, size, corner radius, icons, running dots, badges, separator and trash
state, at the same place on screen.

Pinned apps grouped on the left, running apps to the right of the chevron:

![shown](screenshots/shown.png)

After clicking the chevron, only the pinned group and the Trash remain:

![hidden](screenshots/hidden.png)

The item list is Apple's own Dock, read through Accessibility (`AXList` of the Dock
process: app, separator and trash items with their sizes, titles, URLs and running
state), so it mirrors the real Dock's order and contents. It re-reads and re-renders
on app launch, termination and activation.

The menu bar item's "Hide unpinned apps" hides every app right of the pinned group
(Finder and the Dock's persistent apps); the Trash and its separator stay. Clicking
any separator in the strip toggles the same setting, without moving focus. The
separator at the pinned/unpinned boundary shows a chevron: "<" collapses, ">" expands.
Hovering a tile shows its name in a pill above it, like the real Dock. Clicking a
tile launches the app, or brings it to the front (restoring a fully minimized one);
the Trash opens in Finder. Badge counts come from the Dock's `AXStatusLabel`; custom
overlays some apps paint themselves are not exposed and are not shown.

## Replacing Apple's Dock

On launch the app hides Apple's Dock by setting `com.apple.dock` `autohide` to true
with an `autohide-delay` of 1000 seconds and restarting the Dock, after remembering
the previous values in its own defaults (`restoreAutohide`, `restoreAutohideDelay`).
The Dock keeps running hidden, which is what the strip reads its items from. Quit
from the menu bar item writes the previous values back and restarts the Dock again.
If the app is killed instead of quit, the next launch keeps the remembered values
and the next clean quit restores them. To restore by hand:

```sh
defaults write com.apple.dock autohide -bool false; defaults delete com.apple.dock autohide-delay; killall Dock
```

## Install

```sh
../install.sh my-dock
```

Builds, copies the app to `~/Applications` and starts it through launchd, so it
also runs at login. `../uninstall.sh my-dock` reverses it.

## Build

For development, without installing:

```sh
./build.sh
open MyDock.app
```

`build.sh` compiles `main.swift`, wraps the binary into `MyDock.app` and signs it
with the "mac-utilities" certificate, so macOS keeps the granted Accessibility
permission stable across rebuilds.

## Permissions

Grant Accessibility to `MyDock.app` in
System Settings > Privacy & Security > Accessibility, then relaunch it.
Without it the Dock item list cannot be read and the app exits.

## Dev

Render once, print the window frame and item list, capture the strip to
`/tmp/my-dock-smoke.png` and exit:

```sh
MY_DOCK_SMOKE_TEST=1 MY_DOCK_SMOKE_HIDE=1 ./MyDock.app/Contents/MacOS/my-dock
```

`MY_DOCK_SMOKE_HIDE=1/0` writes the "Hide unpinned apps" preference before rendering
and `MY_DOCK_SMOKE_HOVER=<index>` shows the tooltip of that item before the capture.

The capture is a screen-region capture of our own windows around the strip, so it
needs no Screen Recording permission. A smoke run hides Apple's Dock like a normal
launch and exits without restoring it; the next clean quit of the app restores it.

Always launch with `install.sh`, launchd or `open MyDock.app`. Running the binary
directly from a terminal makes the terminal the responsible process for the
Accessibility permission.
