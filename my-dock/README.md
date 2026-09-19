# my-dock

Menu bar app that renders a floating strip replicating the macOS 27 Dock one-to-one:
same glass, size, corner radius, icons, running dots, separator and trash state.
Rendering only: it ignores the mouse, and the menu bar item only has Quit.

The item list is Apple's own Dock, read through Accessibility (`AXList` of the Dock
process: app, separator and trash items with their sizes, titles, URLs and running
state), so it mirrors the real Dock's order and contents. It re-reads and re-renders
on app launch, termination and activation.

The menu bar item's "Hide unpinned apps" hides every app right of the pinned group
(Finder and the Dock's persistent apps); the Trash and its separator stay. Clicking
any separator in the strip toggles the same setting, without moving focus. The
separator at the pinned/unpinned boundary shows a chevron: "<" collapses, ">" expands.

`comparisonOffset` in `main.swift` floats the strip 70pt above the real Dock for
side-by-side inspection. Set it to 0 when it replaces the Dock.

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

`MY_DOCK_SMOKE_HIDE=1/0` writes the "Hide unpinned apps" preference before rendering.

The capture is a screen-region capture of our own windows around the strip, so it
needs no Screen Recording permission. The real Dock is another process and is not in
the capture.

Always launch with `install.sh`, launchd or `open MyDock.app`. Running the binary
directly from a terminal makes the terminal the responsible process for the
Accessibility permission.
