# mac-utilities

Self-built macOS utilities, one folder per tool.

- `app-switcher/` — menu bar app replacing Cmd+Tab with a whitelist-filtered switcher.

## Setup

Run `./create-signing-cert.sh` once. It creates a self-signed "mac-utilities" certificate that every `build.sh` signs with, so rebuilt apps keep their Accessibility permission. If a rebuilt app asks for permission again, run `tccutil reset Accessibility <bundle id>` and grant it once more.
