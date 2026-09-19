# MyDock

A standalone macOS Dock with a collapsible group of app icons. Requires macOS 26 or later and Xcode command-line tools to build. No third-party app is needed.

- Drag an icon to reorder it.
- Drop an icon on the chevron to move it into the hidden group, even while collapsed.
- Click the chevron to expand the group. Drag an app back to the left to make it visible.
- Right-click an icon for **Move to Hidden/Visible Group**, **Keep in MyDock**, **Open**, **Show in Finder**, and **Quit**.
- Drag `.app` bundles from Finder into either group to keep them there. This saves references; it does not move app files.
- Dropping outside MyDock or on Trash cancels the move. Hidden apps keep running, retain their windows, and remain in Cmd+Tab.
- With Accessibility access, MyDock shortens maximized desktop windows to leave room above the strip. This happens after macOS maximizes the window, so a second resize can be visible.

On first launch, MyDock imports Apple's pinned apps into the visible group. Other running apps enter the hidden group. MyDock then owns its order and saves it to `~/Library/Application Support/MyDock/apps.json`. Group membership and **Keep in MyDock** are separate: an app that is not kept appears only while running, but its assigned group is remembered for its next launch.

## Install

From the repository root:

```sh
./install.sh my-dock
./my-dock/native-dock.sh enable
```

The first command builds, signs, installs to `~/Applications`, and starts MyDock at login. The second moves Apple's Dock to the left and enables auto-hide. Its previous settings are saved before the change. Apple’s Dock remains running for system features. It can still appear if you move to the left screen edge.

To restore Apple's Dock settings:

```sh
./my-dock/native-dock.sh restore
```

Quit MyDock from its menu bar icon, or remove it with `./uninstall.sh my-dock`. Restore Apple's settings before uninstalling. The saved app groups remain available for reinstalling.

## Build and test

```sh
./my-dock/build.sh
./my-dock/test.sh
```

The tests run with the command-line tools and do not need XCTest. See
[the code guide](ARCHITECTURE.md) for where to add features and which checks cover them.

The build uses the repository's `mac-utilities` signing identity. `install.sh` creates it if needed. Use the installer to replace an existing running version; a process lock prevents duplicate Dock instances.

## Implementation

AppKit owns the panel, native drag sessions, drop indicators, and menus. Order changes are saved only after a valid drop. The panel stays visible and keeps the same position throughout a drag. No global mouse event tap, synthetic mouse event, screenshot cover, or drag forwarding is used.

App icons, groups, and dragging do not require Accessibility or Screen Recording permission. Accessibility access enables maximized-window fitting and notification badges from Apple's Dock. Enable it in **System Settings > Privacy & Security > Accessibility** for those features. Badges depend on what Apple exposes.

MyDock handles application icons and opens Trash. It does not reproduce Apple's minimized-window tiles, folder stacks, app-specific Dock menus, or document drops onto app icons. Window fitting adjusts the focused maximized window after resizing ends; it does not reserve macOS desktop space or replace Apple's snapping. It applies only to the display containing MyDock and apps that allow Accessibility resizing. Floating, half-screen, and true full-screen windows keep their size. Large app lists scale to the screen width.
