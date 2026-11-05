import Foundation
import IOKit.pwr_mgt
import os

private let pmsetPath = "/usr/bin/pmset"
private let logger = Logger(subsystem: "com.ulvifk.mac-utilities", category: "keep-awake")

/// `pmset -a disablesleep`, through the sudoers line install.sh installs, so a closed lid does not sleep the machine. False when sudo refuses it.
@discardableResult
@MainActor func setLidClosedSleepDisabled(_ disabled: Bool) async -> Bool {
    let pmset = Process()
    pmset.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
    pmset.arguments = ["-n", pmsetPath, "-a", "disablesleep", disabled ? "1" : "0"]

    return await withCheckedContinuation { continuation in
        pmset.terminationHandler = { process in
            continuation.resume(returning: process.terminationStatus == 0)
        }
        try! pmset.run()
    }
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

/// True when the lid is closed and macOS's own rule, AppleClamshellCausesSleep, says a closed lid sleeps the Mac. That rule is false while an external display keeps the Mac in closed-display mode on AC power or another process holds clamshell sleep off; the placeholder display WindowServer brings online when no real display is left does not count.
func isClosedLidCausingSleep() -> Bool {
    if !readRootDomainFlag("AppleClamshellState") { return false }
    return readRootDomainFlag("AppleClamshellCausesSleep")
}

func sleepMac() {
    let powerManagement = IOPMFindPowerManagement(kIOMainPortDefault)
    let result = IOPMSleepSystem(powerManagement)
    IOServiceClose(powerManagement)

    if result != kIOReturnSuccess {
        logger.error("IOPMSleepSystem failed: \(result, privacy: .public)")
    }
}

/// False when the property is missing, as AppleClamshellState is on Macs without a lid.
private func readRootDomainFlag(_ key: String) -> Bool {
    let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    let value = IORegistryEntryCreateCFProperty(rootDomain, key as CFString, kCFAllocatorDefault, 0)
    IOObjectRelease(rootDomain)
    return value?.takeRetainedValue() as? Bool == true
}
