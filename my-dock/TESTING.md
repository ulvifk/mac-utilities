# Validation

Validated on macOS 27, Apple Silicon, with the installed command-line tools.

- `./my-dock/test.sh` passed the model/session, pasteboard, and presentation suites.
- `./my-dock/build.sh` compiled with warnings treated as errors and signed the app.
- Installed to `~/Applications/MyDock.app` and checked the original single-row glass appearance.
- Checked visible-icon reordering, moving an icon into the collapsed hidden group, moving it back out, and expanding/collapsing the group.
- Checked Escape cancellation followed by a working toggle. The cancelled move preserved the saved order.
- Compared the final visible and hidden app orders with the saved pre-test snapshot. Both match.

The automated mouse driver sometimes delivered mouse-up before AppKit entered the native drag session. For completed-drop checks, an additional click at the intended destination finished that session. No synthetic-event or polling workaround was added to the app. Physical mouse feel still needs direct use; these checks do not establish full native-Dock parity.

Multi-monitor arrangements, full-screen transitions, and VoiceOver navigation have not been fully exercised. The app continues to use the primary display and does not reserve desktop space.
