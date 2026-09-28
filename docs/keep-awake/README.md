# keep-awake

Feature of `MacUtilities.app` that keeps the Mac awake from the menu bar, the port of
a `caffeinate -d` plus `pmset -a disablesleep 1` shell script. The menu bar popover
gets a Keep Awake tile while the feature is enabled; its round toggle fills orange
while active, and the menu bar icon turns into a coffee cup.

While active the app holds a power assertion of its own (no `caffeinate` process) and,
with "Keep awake with the lid closed" on, also runs `sudo -n /usr/bin/pmset -a
disablesleep 1`, so closing the lid does not sleep the machine. The assertion is
`PreventUserIdleDisplaySleep` in that mode, like `caffeinate -d`; with the lid switch
off it is `PreventUserIdleSystemSleep` and no `pmset` call is made, so only idle
sleep is held off and the display may still sleep.

## The tile

The round toggle turns Keep Awake on for the "Turn off after" time, or off again. Its
subtitle reads "Off", "On until turned off", or counts down the time left second by
second, "1:29:05 left".

A set time ends on a one-shot timer at the deactivation date, on the wall clock, so a
Mac that slept past it turns Keep Awake off on waking.

## Settings tab

- Turn off after: 30 minutes, 1 hour, 2 hours or until turned off.
- Keep awake with the lid closed: on by default.

Both apply the next time Keep awake is turned on.

## What is restored, and when

`pmset -a disablesleep 1` outlives the process that set it, so it is put back to `0`:

- when Keep awake is toggled off, its time is up, the feature is switched off in
  Settings > General or the app quits (`applicationWillTerminate` stops every enabled
  feature);
- when the app dies any other way: activating spawns a child watchdog shell that
  outlives the app, `while kill -0 <pid>; do sleep 5; done; sudo -n /usr/bin/pmset -a
  disablesleep 0`, and is killed again on deactivation. So after a crash sleep is
  back to normal within five seconds.

After a power loss or kernel panic while active no process survives to restore it,
so `disablesleep` stays `1` until Keep awake is toggled again or `uninstall.sh` runs.

`uninstall.sh` runs `pmset -a disablesleep 0` once more before removing the sudoers
line, in case the app was killed while active.

## The sudoers line

`pmset -a disablesleep` needs root. `install.sh` writes
`/etc/sudoers.d/mac-utilities-pmset` with

```
<user> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

for the installing user, after checking it with `visudo -c`; nothing else can be run
through it. `uninstall.sh` removes the file. Without it sudo refuses the `pmset`
call, Keep awake stays off with nothing held, and the tile's subtitle turns orange,
"Couldn't keep a closed lid awake: run install.sh, or turn the lid option off in
Settings", until the next time it is turned on.

## Code

`Sources/MacUtilities/Features/KeepAwake/`: `KeepAwakeFeature` publishes the current
`KeepAwakeSession` to `KeepAwakeTile`, its tile in the menu bar popover, and ends it
on the one-shot timer; the session holds the `PowerAssertion` and, with the lid switch
on, the watchdog from `LidClosedSleep`; `KeepAwakePreferences` keeps the
`KeepAwakeAutoOff` choice and the lid switch in UserDefaults for
`KeepAwakeSettingsView`, the settings tab.
