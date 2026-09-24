# keep-awake

Feature of `MacUtilities.app` that keeps the Mac awake from the menu bar, the port of
a `caffeinate -d` plus `pmset -a disablesleep 1` shell script. The menu bar menu
gets a "Keep awake" entry while the feature is enabled; it is checked while active,
and the menu bar icon turns into a coffee cup.

While active the app holds a power assertion of its own (no `caffeinate` process) and,
with "Keep awake with the lid closed" on, also runs `sudo -n /usr/bin/pmset -a
disablesleep 1`, so closing the lid does not sleep the machine. The assertion is
`PreventUserIdleDisplaySleep` in that mode, like `caffeinate -d`; with the lid switch
off it is `PreventUserIdleSystemSleep` and no `pmset` call is made, so only idle
sleep is held off and the display may still sleep.

## Settings tab

- Turn off after: 30 minutes, 1 hour, 2 hours or until turned off. With a timer set
  the menu entry reads "Keep awake (1 h 29 min left)" and is refreshed once a minute.
- Keep awake with the lid closed: on by default.

Both apply the next time Keep awake is turned on.

## What is restored, and when

`pmset -a disablesleep 1` outlives the process that set it, so it is put back to `0`:

- when Keep awake is toggled off, the feature is switched off in Settings > General
  or the app quits (`applicationWillTerminate` stops every enabled feature);
- when the app dies any other way: activating spawns a detached watchdog shell,
  `while kill -0 <pid>; do sleep 5; done; sudo -n /usr/bin/pmset -a disablesleep 0`,
  that is killed again on deactivation. So after a crash sleep is back to normal
  within five seconds.

`uninstall.sh` runs `pmset -a disablesleep 0` once more before removing the sudoers
line, in case the app was killed while active.

## The sudoers line

`pmset -a disablesleep` needs root. `install.sh` writes
`/etc/sudoers.d/mac-utilities-pmset` with

```
<user> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

for the installing user, after checking it with `visudo -c`; nothing else can be run
through it. `uninstall.sh` removes the file. Without it the `pmset` call fails, the
app prints a hint to run `install.sh`, and the assertion alone still holds off idle
sleep.

## Code

`Sources/MacUtilities/Features/KeepAwake/`: `KeepAwakeFeature` owns the menu entry,
the minute timer and the current `KeepAwakeSession`, which holds the
`PowerAssertion` and, with the lid switch on, the watchdog from `LidClosedSleep`;
`KeepAwakePreferences` keeps the `KeepAwakeAutoOff` choice and the lid switch in
UserDefaults for `KeepAwakeSettingsView`, the settings tab.
