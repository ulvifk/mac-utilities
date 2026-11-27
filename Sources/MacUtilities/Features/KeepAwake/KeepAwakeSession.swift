import Foundation
import IOKit.pwr_mgt

/// Owns the power assertion and watchdog until sleep is restored successfully.
final class KeepAwakeSession {
    /// How long it was set to last when it began.
    let autoOff: KeepAwakeAutoOff
    /// nil when the session runs until turned off.
    let deactivationDate: Date?
    let keepsAwakeWithLidClosed: Bool

    private let powerManagement: PowerManagement

    private var assertionID: IOPMAssertionID!
    private var lidClosedSleepWatchdog: Process?

    init(autoOff: KeepAwakeAutoOff, deactivationDate: Date?, keepsAwakeWithLidClosed: Bool, powerManagement: PowerManagement) {
        self.autoOff = autoOff
        self.deactivationDate = deactivationDate
        self.keepsAwakeWithLidClosed = keepsAwakeWithLidClosed
        self.powerManagement = powerManagement
    }

    /// False when sudo refuses to disable lid-closed sleep; nothing is held then.
    @MainActor func begin() async -> Bool {
        if !keepsAwakeWithLidClosed {
            assertionID = powerManagement.createAssertion(type: kIOPMAssertionTypePreventUserIdleSystemSleep as String)
            return true
        }

        let watchdog = powerManagement.launchLidClosedSleepWatchdog()
        let didDisableSleep = await powerManagement.setLidClosedSleepDisabled(true)
        if !didDisableSleep {
            powerManagement.terminateLidClosedSleepWatchdog(watchdog)
            return false
        }

        assertionID = powerManagement.createAssertion(type: kIOPMAssertionTypePreventUserIdleDisplaySleep as String)
        lidClosedSleepWatchdog = watchdog
        return true
    }

    /// False when sudo refuses to restore lid-closed sleep; the assertion and watchdog are kept then, so end can be retried.
    @MainActor func end() async -> Bool {
        if let lidClosedSleepWatchdog {
            let didRestoreSleep = await powerManagement.setLidClosedSleepDisabled(false)
            if !didRestoreSleep { return false }
            powerManagement.terminateLidClosedSleepWatchdog(lidClosedSleepWatchdog)
        }

        powerManagement.releaseAssertion(assertionID)
        return true
    }
}
