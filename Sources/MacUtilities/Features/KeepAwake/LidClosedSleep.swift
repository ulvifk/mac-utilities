import CoreGraphics
import Foundation
import IOKit.graphics
import IOKit.pwr_mgt

private let pmsetPath = "/usr/bin/pmset"

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

/// True when macOS would sleep the Mac for its lid: the lid is closed and no external display keeps the Mac in closed-display mode.
func isLidClosedWithoutExternalDisplay() -> Bool {
    if !isLidClosed() { return false }
    return !isExternalDisplayConnected()
}

func sleepMac() {
    let powerManagement = IOPMFindPowerManagement(kIOMainPortDefault)
    IOPMSleepSystem(powerManagement)
    IOServiceClose(powerManagement)
}

private func isLidClosed() -> Bool {
    let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    let clamshellState = IORegistryEntryCreateCFProperty(rootDomain, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)
    IOObjectRelease(rootDomain)
    return clamshellState?.takeRetainedValue() as? Bool == true // Macs without a lid have no clamshell state
}

/// True when any online display is not the built-in panel, AirPlay and Sidecar displays included.
private func isExternalDisplayConnected() -> Bool {
    var displayCount: UInt32 = 0
    CGGetOnlineDisplayList(0, nil, &displayCount)
    var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
    CGGetOnlineDisplayList(displayCount, &displays, &displayCount)
    return displays.contains(where: isExternalDisplay)
}

/// Skips the placeholder display WindowServer brings online when no real display is left, as with the lid closed and nothing plugged in; it is not built in and has an unknown vendor.
private func isExternalDisplay(_ display: CGDirectDisplayID) -> Bool {
    if CGDisplayIsBuiltin(display) != 0 { return false }
    return CGDisplayVendorNumber(display) != kDisplayVendorIDUnknown
}
