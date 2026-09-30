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

- The round toggle turns Keep Awake on for the "Turn off after" time, or off again.
  Its subtitle reads "Off", "Turning on…", "Restoring sleep…", "On, never turns
  off", or counts down the time left second by second, "1:29:05 left".
  With the power option on, a session paused on battery reads "Waiting for power".
- Under it, the chips 30 min, 1 hr, 2 hr and ∞ (Never) turn Keep Awake on for that
  long from now; the one in use is filled orange. A chip clicked while it is on starts
  it over for the new time, re-reading both settings. The chip clicked also becomes
  "Turn off after" in the settings pane, so the round toggle and the `toggleKeepAwake`
  hotkey use that time from then on.
- Below the chips, "Only while connected to power" changes the same saved option
  as the settings pane and applies immediately. It is grayed out and disabled while
  Keep Awake is off; its saved value is kept.

A set time ends on a one-shot timer at the deactivation date, on the wall clock, so a
Mac that slept past it turns Keep Awake off on waking.

If restoring sleep fails, the tile stays on and shows a warning. The app retries
every five seconds; clicking the round toggle retries immediately. A duration chip
waits until the previous session restores sleep, then applies the latest requested
duration. Further clicks update the pending request; power commands run one at a
time. The commands complete asynchronously, so the keyboard tap and menu remain
responsive while a command is pending.

## Settings pane

- Turn off after: 30 min, 1 hr, 2 hr or Never, side by side in one segmented
  control; the chips set it too.
- Keep awake with the lid closed: on by default. The line under it says it runs
  `pmset` as root and what is held off without it.
- Only while connected to power: off by default and saved across launches. With it
  on, disconnecting external power releases the assertion and restores lid-closed
  sleep. The session waits on battery; the tile toggle, duration chips and hotkey
  can enable it, but cannot hold off sleep until external power returns. Reconnecting
  resumes the enabled session with its original deadline. Turning it off manually,
  disabling the feature or reaching the deadline clears that session, so reconnecting
  cannot turn it back on.

The duration and lid options apply the next time Keep Awake is turned on. The power
option applies immediately, including to an active session. Turning it off allows
an enabled session to resume on battery.

## What is restored, and when

`pmset -a disablesleep 1` outlives the process that set it, so it is put back to `0`:

- when Keep Awake is toggled off, its time is up, the feature is switched off in its
  settings pane or the app quits. Quit stops enabled features, then waits for
  outstanding Keep Awake commands before allowing the app to exit, including
  cleanup still owned by a disabled feature;
- when external power is disconnected with "Only while connected to power" on,
  including when an activation command is still in flight;
- when the app dies any other way: activating spawns a child watchdog shell that
  outlives the app and checks for exit every five seconds. After exit it runs
  `sudo -n /usr/bin/pmset -a disablesleep 0`, retrying every five seconds until
  successful. Deactivation stops the watchdog only after restoration succeeds.

The power assertion, watchdog, session and coffee-cup icon remain active when
restoration fails. The app keeps retrying even after the feature is switched off;
if restoring sleep still fails during Quit, the watchdog takes over after exit.
An activation already in flight finishes before an off request or Quit restores
sleep, so a late `disablesleep 1` command cannot undo cleanup. This also applies
when the auto-off timer expires.

The watchdog watches app exit rather than command completion. The existing crash
recovery has a limitation: an abrupt kill during a slow activation can let the
unfinished command disable sleep after the watchdog has restored it. Graceful
Quit waits for the command and avoids this race.

After a power loss or kernel panic while active no process survives to restore it,
so `disablesleep` stays `1` until Keep Awake is toggled again or `uninstall.sh` runs.

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
call, Keep Awake stays off with nothing held, and the tile's subtitle turns orange,
"Couldn't keep a closed lid awake: run install.sh, or turn the lid option off in
Settings", until the next time it is turned on.

## Code

`Sources/MacUtilities/Features/KeepAwake/`: `KeepAwakeFeature` publishes the current
`KeepAwakeSession` to `KeepAwakeTile`, its tile in the menu bar popover, and ends it
on the one-shot timer. One transition task processes the latest requested session
without canceling external commands; the session holds the `PowerAssertion` and,
with the lid switch on, the watchdog from `LidClosedSleep`; `KeepAwakePreferences` keeps the
`KeepAwakeAutoOff` choice, lid switch and power option in UserDefaults for
`KeepAwakeSettingsView`, the settings pane's section, and the tile's chips.
`ExternalPowerSource` watches IOKit power-source changes on the main run loop. The
feature keeps the requested session while it waits on battery and runs its deadline
timer independently of sleep-restoration retries.

App-owned Quit and reopening requests use `ApplicationTermination` to enter AppKit
through its run loop, so queued UI actions finish before deferred Quit waits for
cleanup. Native system termination requests use the same deferred cleanup.
