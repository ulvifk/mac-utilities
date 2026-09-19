# MyDock code guide

MyDock draws one horizontal glass strip. It owns the app list and drag sessions. Keep that visual contract when adding features: the hidden section expands inline, and Apple’s Dock never handles a MyDock drag.

## Where changes belong

| Responsibility | Source |
| --- | --- |
| App membership, pinning, ordering, collapse | `Sources/Model/DockState.swift`, `DockEdit.swift` |
| Save a change before publishing it | `Sources/Application/DockSession.swift` |
| Route user actions and workspace updates | `Sources/Application/MyDockController.swift`, `DockAction.swift` |
| Build the displayed app list | `Sources/Presentation/DockItem.swift` |
| Calculate icon frames and drop targets | `Sources/Presentation/DockLayout.swift` |
| Draw glass details, icons, badges, and drop feedback | `Sources/Presentation/DockRenderer.swift`, `DockAppearance.swift` |
| Handle mouse, menu, accessibility, and drag events | `Sources/Presentation/DockStripView.swift`, `DockAccessibilityElement.swift` |
| Position the strip and tooltips | `Sources/Presentation/DockWindow.swift` |
| Build native menus | `Sources/Presentation/DockMenus.swift` |
| Read app information, pasteboards, badges, and saved files; perform macOS actions | `Sources/Platform/` |

## Add a feature

For a new setting that changes saved state, add a `DockEdit` case and its pure transformation in the model. Route its button or menu through `DockAction.edit`. `DockSession` owns saving, so a menu and a mouse gesture cannot accidentally use different persistence rules.

For an action such as opening an app, add a `DockAction` case and handle it in the controller. Put the macOS call in `ApplicationActions`. Rendering and grouping must never hide or terminate an app.

For a new kind of tile, add a `DockItem` case with the values it requires. The compiler will identify the switches for drawing, sizing, labels, and primary actions that need updating. App-only fields belong to `AppTile`, not to every item as optional values.

For a visual change, edit the renderer or appearance constants. Layout is calculated once and shared by drawing, hit testing, dragging, and accessibility. Test coordinate rules in `Tests/Presentation`.

## Interaction rules

- Do not replace the displayed list while a press, menu, or drag is active. Refresh from current workspace state after the interaction ends.
- A drag preview does not change the saved state. Only an accepted drop sends a `DockEdit`.
- Internal drags export a private app identifier with a move operation limited to MyDock. External app drops save references with copy/link semantics; they never move installed bundles.
- A collapsed chevron remains a drop target. Trash and the desktop reject internal shortcut drops.
- Group assignment survives an app quitting and restarting. Keeping an app in MyDock controls whether it remains displayed while stopped.
- Persisted `apps.json` keeps the existing format. Do not replace it with the separate `layout.json` used by the experimental shelf.

## Checks

Run `./my-dock/test.sh` from the repository root. These are standalone Swift test executables; they do not need XCTest or a full Xcode installation. The model and session tests cover state changes and failed saves. The input tests cover pasteboard validation. The presentation tests cover app visibility, badges, drop boundaries, and allowed operations.

Run `./my-dock/build.sh` for the signed app. The build treats warnings as errors. After changing the interaction code, check real dragging, cancelled drops, menus, and saved order across a restart on macOS.
