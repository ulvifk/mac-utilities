import Foundation

private let pmsetPath = "/usr/bin/pmset"

/// `pmset -a disablesleep`, through the sudoers line install.sh installs, so a closed lid does not sleep the machine. False when sudo refuses it.
@discardableResult
func setLidClosedSleepDisabled(_ disabled: Bool) -> Bool {
    let pmset = Process()
    pmset.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
    pmset.arguments = ["-n", pmsetPath, "-a", "disablesleep", disabled ? "1" : "0"]

    try! pmset.run()
    pmset.waitUntilExit()

    return pmset.terminationStatus == 0
}

/// Retries restoring lid-closed sleep after the app exits until pmset succeeds.
func launchLidClosedSleepWatchdog() -> Process {
    let processIdentifier = ProcessInfo.processInfo.processIdentifier
    let watchdog = Process()
    watchdog.executableURL = URL(fileURLWithPath: "/bin/sh")
    watchdog.arguments = ["-c", "while kill -0 \(processIdentifier) 2>/dev/null; do sleep 5; done; until sudo -n \(pmsetPath) -a disablesleep 0; do sleep 5; done"]

    try! watchdog.run()
    return watchdog
}
