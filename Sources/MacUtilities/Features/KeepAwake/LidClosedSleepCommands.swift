import Foundation

private let pmsetPath = "/usr/bin/pmset"

/// sudo -n pmset -a disablesleep 0 or 1, through the sudoers line install.sh installs; not yet launched.
func buildLidClosedSleepCommand(disabled: Bool) -> Process {
    let command = Process()
    command.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
    command.arguments = ["-n", pmsetPath, "-a", "disablesleep", disabled ? "1" : "0"]
    return command
}

/// A shell that waits for the given process to exit, then retries restoring lid-closed sleep every five seconds until pmset succeeds; not yet launched.
func buildLidClosedSleepWatchdog(watching processIdentifier: Int32) -> Process {
    let watchdog = Process()
    watchdog.executableURL = URL(fileURLWithPath: "/bin/sh")
    watchdog.arguments = ["-c", "while kill -0 \(processIdentifier) 2>/dev/null; do sleep 5; done; until sudo -n \(pmsetPath) -a disablesleep 0; do sleep 5; done"]
    return watchdog
}

/// Launches the process and returns its exit status, leaving the main thread free while it runs.
@MainActor func runProcess(_ process: Process) async -> Int32 {
    return await withCheckedContinuation { continuation in
        process.terminationHandler = { process in
            continuation.resume(returning: process.terminationStatus)
        }
        try! process.run()
    }
}
