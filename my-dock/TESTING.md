# Validation

Validated on macOS 27, Apple Silicon, with the installed command-line tools.

- `./my-dock/test.sh` passed the model/session, pasteboard, presentation, and window-space suites.
- `./my-dock/build.sh` compiled with warnings treated as errors and signed the app.
- Installed to `~/Applications/MyDock.app` and checked the original single-row glass appearance.
- Checked visible-icon reordering, moving an icon into the collapsed hidden group, moving it back out, and expanding/collapsing the group.
- Checked Escape cancellation followed by a working toggle. The cancelled move preserved the saved order.
- Compared the final visible and hidden app orders with the saved pre-test snapshot. Both match.
- Checked Chrome's desktop **Fill** action and return to the previous size. Window fitting shortens the maximized window afterward. The visible second resize is a known limitation, accepted while native space reservation is investigated.
- Entered and exited Chrome's true full-screen mode without shortening the window.

The automated mouse driver sometimes delivered mouse-up before AppKit entered the native drag session. For completed-drop checks, an additional click at the intended destination finished that session. No synthetic-event or polling workaround was added to the app. Physical mouse feel still needs direct use; these checks do not establish full native-Dock parity.

Physical multi-monitor arrangements, broader full-screen transitions, and VoiceOver navigation have not been fully exercised. The app uses the primary display. The window-fitting tests cover geometry, but the top-edge drag gesture still needs a physical mouse check. Fitting adjusts a window after maximization; it does not reserve desktop space in advance.
