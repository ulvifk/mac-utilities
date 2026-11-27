import Foundation
import IOKit.ps
import IOKit.pwr_mgt
import os

private let logger = Logger(subsystem: "com.ulvifk.mac-utilities", category: "keep-awake")

final class SystemPowerManagement: PowerManagement {
    private var externalPowerObservation: CFRunLoopSource?
    private var onExternalPowerChange: (() -> Void)?

    deinit {
        if let externalPowerObservation { CFRunLoopSourceInvalidate(externalPowerObservation) }
    }

    func createAssertion(type: String) -> IOPMAssertionID {
        var id = IOPMAssertionID(0)
        IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "MacUtilities Keep awake" as CFString, &id)
        return id
    }

    func releaseAssertion(_ id: IOPMAssertionID) {
        IOPMAssertionRelease(id)
    }

    @MainActor func setLidClosedSleepDisabled(_ disabled: Bool) async -> Bool {
        return await runProcess(buildLidClosedSleepCommand(disabled: disabled))
    }

    func launchLidClosedSleepWatchdog() -> Process {
        let watchdog = buildLidClosedSleepWatchdog(watching: ProcessInfo.processInfo.processIdentifier)
        try! watchdog.run()
        return watchdog
    }

    func terminateLidClosedSleepWatchdog(_ watchdog: Process) {
        watchdog.terminate()
    }

    /// Reads AppleClamshellCausesSleep, macOS's own rule. It is false while an external display keeps the Mac in closed-display mode on AC power or another process holds clamshell sleep off; the placeholder display WindowServer brings online when no real display is left does not count.
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

    func isConnectedToExternalPower() -> Bool {
        let information = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sourceType = IOPSGetProvidingPowerSourceType(information).takeUnretainedValue() as String
        return sourceType == kIOPSACPowerValue
    }

    func startObservingExternalPower(_ onChange: @escaping () -> Void) {
        onExternalPowerChange = onChange

        let observation = IOPSNotificationCreateRunLoopSource({ context in
            let powerManagement = Unmanaged<SystemPowerManagement>.fromOpaque(context!).takeUnretainedValue()
            powerManagement.onExternalPowerChange!()
        }, Unmanaged.passUnretained(self).toOpaque()).takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), observation, .commonModes)
        externalPowerObservation = observation
    }

    /// False when the property is missing, as AppleClamshellState is on Macs without a lid.
    private func readRootDomainFlag(_ key: String) -> Bool {
        let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        let value = IORegistryEntryCreateCFProperty(rootDomain, key as CFString, kCFAllocatorDefault, 0)
        IOObjectRelease(rootDomain)
        return value?.takeRetainedValue() as? Bool == true
    }
}
