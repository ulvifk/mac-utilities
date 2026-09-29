import Foundation
import IOKit.pwr_mgt

/// Owns the power assertion and watchdog until sleep is restored successfully.
final class KeepAwakeSession {
    /// How long it was set to last when it began.
    let autoOff: KeepAwakeAutoOff
    /// nil when the session runs until turned off.
    let deactivationDate: Date?

    private let keepsAwakeWithLidClosed: Bool
    private var assertion: PowerAssertion!
    private var lidClosedSleepWatchdog: Process?

    init(preferences: KeepAwakePreferences) {
        autoOff = preferences.autoOff
        deactivationDate = autoOff.duration.map { Date(timeIntervalSinceNow: $0) }
        keepsAwakeWithLidClosed = preferences.keepsAwakeWithLidClosed
    }

    @MainActor func begin() async -> Bool {
        if !keepsAwakeWithLidClosed {
            assertion = PowerAssertion(type: kIOPMAssertionTypePreventUserIdleSystemSleep as String)
            return true
        }

        let watchdog = launchLidClosedSleepWatchdog()
        let didDisableSleep = await setLidClosedSleepDisabled(true)
        if !didDisableSleep {
            watchdog.terminate()
            return false
        }

        assertion = PowerAssertion(type: kIOPMAssertionTypePreventUserIdleDisplaySleep as String)
        lidClosedSleepWatchdog = watchdog
        return true
    }

    @MainActor func end() async -> Bool {
        if let lidClosedSleepWatchdog {
            let didRestoreSleep = await setLidClosedSleepDisabled(false)
            if !didRestoreSleep { return false }
            lidClosedSleepWatchdog.terminate()
        }

        assertion.release()
        return true
    }
}
