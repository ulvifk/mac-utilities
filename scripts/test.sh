#!/bin/bash
# Runs the test suite; arguments go to swift test. The Command Line Tools keep the Swift Testing macro plugin outside the compiler's default
# plugin path, so it is passed when it is there. Xcode's toolchain finds its own.
set -euo pipefail
cd "$(dirname "$0")/.."

TESTING_PLUGINS="$(xcode-select -p)/usr/lib/swift/host/plugins/testing"

if [ -d "$TESTING_PLUGINS" ]; then
    swift test -Xswiftc -plugin-path -Xswiftc "$TESTING_PLUGINS" "$@"
    exit
fi

swift test "$@"
