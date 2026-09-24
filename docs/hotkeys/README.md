# hotkeys

Feature of `MacUtilities.app` that binds global key combos to actions: jump to the
terminal or launch it, hide it again, run a shell line, toggle keep-awake. The
bindings live in a JSON file you can edit by hand and version; the Hotkeys tab of
the settings window is the friendly front to the same file.

A bound combo is swallowed by the event tap, so the focused app never sees it. The
combo must match exactly: a binding on ⌘⌥T does not fire on ⌘⌥⇧T. Holding the key
down does not repeat the action.

## The file

`$XDG_CONFIG_HOME/mac-utilities/hotkeys.json`, that is
`~/.config/mac-utilities/hotkeys.json` unless `XDG_CONFIG_HOME` is set. A list of
bindings, each with a `key` and an `action`:

```json
[
  {
    "key": { "keyCode": 17, "modifiers": ["option", "command"] },
    "action": { "type": "activateApp", "target": "com.apple.Terminal" }
  },
  {
    "key": { "keyCode": 49, "modifiers": ["control"] },
    "action": { "type": "runCommand", "target": "open -a Finder ~/Downloads" }
  },
  {
    "action": { "type": "toggleKeepAwake", "target": "" }
  }
]
```

- `keyCode` is the virtual key code of the key (17 is T, 49 is Space on every
  layout; letters follow the current layout). The settings tab records it for you;
  for hand edits the common ones are: A 0, S 1, D 2, F 3, H 4, G 5, Z 6, X 7, C 8,
  V 9, B 11, Q 12, W 13, E 14, R 15, Y 16, T 17, 1 18, 2 19, 3 20, 4 21, 6 22, 5 23,
  9 25, 7 26, 8 28, 0 29, O 31, U 32, I 34, P 35, L 37, J 38, K 40, N 45, M 46,
  Return 36, Tab 48, Space 49, Escape 53, Left 123, Right 124, Down 125, Up 126,
  F1 122, F2 120, F3 99, F4 118, F5 96, F6 97, F7 98, F8 100, F9 101, F10 109,
  F11 103, F12 111.
- `modifiers` holds any of `control`, `option`, `shift`, `command`, in any order.
- A binding without a `key` is kept but never fires; that is what "Add binding"
  writes until a shortcut is recorded.
- `type` is one of the actions below; `target` is what it acts on.

The file is written on every change made in the tab (pretty-printed, keys sorted)
and the directory is watched, so a hand edit applies on the spot while the app runs.
A file that does not parse is reported on stdout and the bindings in use stay as they
were until it parses again.

## Actions

- `activateApp`: `target` is a bundle identifier. Brings the app's windows to the
  front, launching it first when it is not running.
- `toggleApp`: same target. Hides the app when it is frontmost, otherwise the same
  as `activateApp`.
- `runCommand`: `target` is a command line, run through `/bin/sh -c` and not waited
  for; it outlives the app.
- `toggleKeepAwake`: `target` is empty. Toggles the Keep awake menu entry, the same
  as clicking it. Does nothing while the keep-awake feature is switched off in
  Settings > General.

## Settings tab

One row per binding: the recorder button, the action, its target and a warning when
the key is taken. Click the recorder and press the combo; it shows as symbols
(⌥⌘T). Esc or a click elsewhere stops recording. Only combos with at least one
modifier are recorded; a bare function key can still be set in the file. A combo
that is already bound fires its action instead of being recorded again, since the
tap swallows it before the window sees it: clear the other binding first.

The target is an app picker (every `.app` in `/Applications`, `/System/Applications`,
`~/Applications` and their `Utilities` folders, with icons) for the app actions, a
text field for the command, nothing for keep-awake. Changing the action clears the
target.

The warning names the other binding with the same key, or the macOS use of a
reserved combo: Cmd+Space (Spotlight), Cmd+Tab and Cmd+Shift+Tab (app switching,
claimed by macOS or the app-switcher feature either way), Cmd+Option+Esc, Ctrl+Cmd+Q,
Cmd+Shift+3/4/5 and Ctrl+arrows. A warned binding is still saved and still fires
where the tap sees the key first.

Every change is written to the file at once; there is no save button. The tab shows
the path of the file it edits in its footer.

## Code

`Sources/MacUtilities/Features/Hotkeys/`: `HotkeysFeature` matches tapped key
presses against the bindings and runs the action off the tap through
`PerformHotkeyAction`; `HotkeyBindingsStore` reads and writes the file and watches the
directory; `HotkeyBinding`, `KeyCombo`, `ModifierKey`, `HotkeyAction` and
`HotkeyActionType` are the file's shape, with `KeyNames` turning key codes into
labels; `HotkeysSettingsView` lists a `HotkeyBindingRow` per binding, built from
`KeyRecorderField` (wrapping `KeyRecorderButton`), `AppPicker` over `InstalledApps`
and the warnings from `HotkeyConflicts`.
