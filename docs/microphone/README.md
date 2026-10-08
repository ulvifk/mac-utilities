# Microphone

Choose the Mac's default audio input from the **Microphone** selector in the menu
bar tile or Settings > Microphone. The selector lists all available macOS audio
inputs, including built-in microphones, USB microphones, Bluetooth headsets and
iPhone Continuity Camera microphones. The current input appears by name.

## Selection and restoration

Enabling the feature makes its tile available and observes audio inputs. It does
not change the default microphone until you select a different input.
The list refreshes when devices connect or disconnect, and the current selection
follows default-input changes made in Sound settings or other apps.

Selecting a microphone makes it the Mac's default input. The controls show
**Switching microphone…** until macOS confirms the change. During that time,
selection and restoration are disabled. If macOS confirms another input instead,
the request ends with an error and preserves that input. If the requested device
disconnects, the request also ends with an error.

Choose **Restore previous microphone** to turn off the app's selection. Disabling
the feature or quitting also restores the input that was selected before the app
took control. Switching between microphones in MacUtilities preserves that
original input. Disabling or quitting during a pending selection waits for
confirmation and then restores it.

Restoration matches the previous microphone by its persistent device identifier,
so it can still be restored after reconnection. If the previous microphone is
missing, or there was no previous input, the app shows a message and keeps the
current input. You can choose another microphone in the selector or Sound settings.
A failed restoration can be retried with **Restore previous microphone**.

Selecting the current microphone does not take control or create a previous input.
If you change the default microphone elsewhere, MacUtilities releases control and
does not restore the old input later. If the selected microphone disconnects, the
app also releases control. Reconnecting it does not select it automatically.

Apps that follow the system default use the selected microphone. Apps with their
own microphone selection need you to choose it there. MacUtilities changes the
default device; it does not record audio or start an iPhone camera. Apps that
capture audio manage their own microphone permissions.

## Connect an iPhone

macOS provides an iPhone's audio connection through Continuity Camera. No companion
iPhone app or virtual audio driver is needed.

- Sign in to the same Apple Account on both devices with two-factor authentication.
- Enable Continuity Camera in iPhone Settings > General > AirPlay & Continuity.
- Keep the iPhone nearby, locked and stationary. Enable Wi-Fi and Bluetooth on
  both devices, or connect with USB and trust the Mac.

[Apple's Continuity Camera guide](https://support.apple.com/en-us/102546) describes
the supported devices, full requirements and connection troubleshooting.

## Verification

`swift test` checks selection across multiple input types, device-list refresh,
external default changes, disconnect and reconnect, restoration across device ID
changes, failed changes, and disabling or quitting during pending changes.
CoreAudio adapter tests use simulated hardware and do not change the Mac's input.

For a hardware check, connect at least two microphones and select each from the
tile and settings. Confirm the same default in System Settings > Sound > Input.
Disconnect and reconnect a device, then change the input in Sound settings and
confirm MacUtilities follows it. Select a different input through MacUtilities and
check **Restore previous microphone**, feature disable and quit each restore the
original input. After an external change, disable or quit and confirm it is kept.
