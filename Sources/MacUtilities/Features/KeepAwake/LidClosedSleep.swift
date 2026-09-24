import Foundation

private let pmsetPath = "/usr/bin/pmset"

/// `pmset -a disablesleep`, through the sudoers line install.sh installs, so a closed lid does not sleep the machine.
func setLidClosedSleepDisabled(_ disabled: Bool) {
    let pmset = Process()
    pmset.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
    pmset.arguments = ["-n", pmsetPath, "-a", "disablesleep", disabled ? "1" : "0"]

    try! pmset.run()
    pmset.waitUntilExit()

    if pmset.terminationStatus == 0 { return }
    print("pmset -a disablesleep failed with status \(pmset.terminationStatus): run install.sh to install the sudoers line.")
}

/// A shell that outlives the app and re-enables lid-closed sleep once this process is gone, so a crash never leaves it disabled.
func launchLidClosedSleepWatchdog() -> Process {
    let processIdentifier = ProcessInfo.processInfo.processIdentifier
    let watchdog = Process()
    watchdog.executableURL = URL(fileURLWithPath: "/bin/sh")
    watchdog.arguments = ["-c", "while kill -0 \(processIdentifier); do sleep 5; done; sudo -n \(pmsetPath) -a disablesleep 0"]

    try! watchdog.run()
    return watchdog
}
