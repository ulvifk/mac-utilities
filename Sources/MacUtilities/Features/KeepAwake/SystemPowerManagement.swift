import Foundation
import IOKit.ps
import IOKit.pwr_mgt
import os

final class SystemPowerManagement: PowerManagement {
    private var externalPowerObservation: CFRunLoopSource?
    private var onExternalPowerChange: (() -> Void)?
    private var powerSourceType: String! // the providing power source as last logged, such as "AC Power" or "Battery Power"

    deinit {
        if let externalPowerObservation { CFRunLoopSourceInvalidate(externalPowerObservation) }
    }

    func createAssertion(type: String) -> IOPMAssertionID {
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "MacUtilities Keep awake" as CFString, &id)
        if result == kIOReturnSuccess {
            Logger.keepAwake.notice("Power assertion \(id, privacy: .public) created: \(type, privacy: .public)")
        } else {
            Logger.keepAwake.error("Power assertion \(type, privacy: .public) not created: IOPMAssertionCreateWithName returned \(result, privacy: .public)")
        }
        return id
    }

    func releaseAssertion(_ id: IOPMAssertionID) {
        IOPMAssertionRelease(id)
        Logger.keepAwake.notice("Power assertion \(id, privacy: .public) released")
    }

    @MainActor func setLidClosedSleepDisabled(_ disabled: Bool) async -> Bool {
        let value = disabled ? 1 : 0
        let status = await runProcess(buildLidClosedSleepCommand(disabled: disabled))
        if status == 0 {
            Logger.keepAwake.notice("pmset -a disablesleep \(value, privacy: .public) succeeded")
        } else {
            Logger.keepAwake.error("pmset -a disablesleep \(value, privacy: .public) failed: sudo exited with status \(status, privacy: .public)")
        }
        return status == 0
    }

    func launchLidClosedSleepWatchdog() -> Process {
        let watchdog = buildLidClosedSleepWatchdog(watching: ProcessInfo.processInfo.processIdentifier)
        try! watchdog.run()
        Logger.keepAwake.notice("Lid-closed sleep watchdog launched: pid \(watchdog.processIdentifier, privacy: .public)")
        return watchdog
    }

    func terminateLidClosedSleepWatchdog(_ watchdog: Process) {
        watchdog.terminate()
        Logger.keepAwake.notice("Lid-closed sleep watchdog terminated: pid \(watchdog.processIdentifier, privacy: .public)")
    }

    /// Reads AppleClamshellCausesSleep, macOS's own rule. It is false while an external display keeps the Mac in closed-display mode on AC power or another process holds clamshell sleep off; the placeholder display WindowServer brings online when no real display is left does not count.
    func isClosedLidCausingSleep() -> Bool {
        let isLidClosed = readRootDomainFlag("AppleClamshellState")
        let doesClosedLidCauseSleep = readRootDomainFlag("AppleClamshellCausesSleep")
        Logger.keepAwake.notice("AppleClamshellState \(isLidClosed, privacy: .public), AppleClamshellCausesSleep \(doesClosedLidCauseSleep, privacy: .public)")

        return isLidClosed && doesClosedLidCauseSleep
    }

    func sleepMac() {
        let powerManagement = IOPMFindPowerManagement(kIOMainPortDefault)
        let result = IOPMSleepSystem(powerManagement)
        IOServiceClose(powerManagement)

        if result != kIOReturnSuccess {
            Logger.keepAwake.error("IOPMSleepSystem failed: \(result, privacy: .public)")
        }
    }

    func isConnectedToExternalPower() -> Bool {
        return getPowerSourceType() == kIOPSACPowerValue
    }

    func startObservingExternalPower(_ onChange: @escaping () -> Void) {
        onExternalPowerChange = onChange
        powerSourceType = getPowerSourceType()
        Logger.keepAwake.notice("Power source: \(self.powerSourceType, privacy: .public)")

        let observation = IOPSNotificationCreateRunLoopSource({ context in
            let powerManagement = Unmanaged<SystemPowerManagement>.fromOpaque(context!).takeUnretainedValue()
            powerManagement.handlePowerSourceChange()
        }, Unmanaged.passUnretained(self).toOpaque()).takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), observation, .commonModes)
        externalPowerObservation = observation
    }

    /// IOKit notifies on every power source update, battery level included; only a change of the providing source is logged.
    private func handlePowerSourceChange() {
        let newPowerSourceType = getPowerSourceType()
        if newPowerSourceType != powerSourceType {
            Logger.keepAwake.notice("Power source changed: \(self.powerSourceType, privacy: .public) -> \(newPowerSourceType, privacy: .public)")
            powerSourceType = newPowerSourceType
        }

        onExternalPowerChange!()
    }

    /// The providing power source, such as "AC Power" or "Battery Power".
    private func getPowerSourceType() -> String {
        let information = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        return IOPSGetProvidingPowerSourceType(information).takeUnretainedValue() as String
    }

    /// False when the property is missing, as AppleClamshellState is on Macs without a lid.
    private func readRootDomainFlag(_ key: String) -> Bool {
        let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        let value = IORegistryEntryCreateCFProperty(rootDomain, key as CFString, kCFAllocatorDefault, 0)
        IOObjectRelease(rootDomain)
        return value?.takeRetainedValue() as? Bool == true
    }
}
