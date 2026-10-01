# iPhone Mic

Select your iPhone as the Mac's default microphone from the menu bar popover.
macOS provides the audio connection through Continuity Camera. No companion
iPhone app or virtual audio driver is needed.

## Setup

- Use an iPhone XR or later with iOS 16 or later.
- Sign in to the same Apple Account on both devices with two-factor authentication.
- Enable Continuity Camera in iPhone Settings > General > AirPlay & Continuity
  (AirPlay & Handoff on older iOS versions).
- Keep the iPhone nearby, locked and stationary. Enable Wi-Fi and Bluetooth on
  both devices, or connect with USB and trust the Mac.
- On a Mac without a built-in camera, place the iPhone in landscape orientation.

Open the MacUtilities popover and turn on **iPhone Mic**. If no iPhone appears,
connect it with USB and check Settings > iPhone Mic for setup instructions.

[Apple's Continuity Camera guide](https://support.apple.com/en-us/102546) describes
the full requirements and connection troubleshooting.

## Behavior

Enabling the feature makes its tile available. It does not switch microphones
until you turn on the tile or the **Use iPhone microphone** switch in Settings.
The feature uses the first available Continuity Camera microphone.

If an iPhone is already the default input, the tile shows it as selected. Its
toggle is disabled because MacUtilities has no previous microphone to restore.
Use Sound settings to select another input.

Turning the tile off, disabling the feature or quitting restores the microphone
that was selected before, if it is still connected. The feature matches that
microphone by its persistent device identifier, so reconnecting it still permits
restoration. If there was no previous microphone or it is disconnected, the app
shows a message and keeps the current input. Select another input in Sound settings.

If you change the default microphone elsewhere, MacUtilities releases control and
does not restore the old input later. If the iPhone disconnects and macOS selects
another input, the tile turns off. It does not switch back automatically.

Apps that follow the system default use the iPhone. Apps with an explicit
microphone selection need you to choose the iPhone in their own settings.
MacUtilities changes the default device; it does not record audio or start the
iPhone camera. Apps that capture audio manage their own microphone permissions.
