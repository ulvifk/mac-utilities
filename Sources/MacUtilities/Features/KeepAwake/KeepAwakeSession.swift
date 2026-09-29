import Foundation
import IOKit.pwr_mgt

/// Owns the power assertion and watchdog until sleep is restored successfully.
final class KeepAwakeSession {
    /// How long it was set to last when it began.
    let autoOff: KeepAwakeAutoOff
    /// nil when the session runs until turned off.
    let deactivationDate: Date?

    private let assertion: PowerAssertion
    private let lidClosedSleepWatchdog: Process?

    init?(preferences: KeepAwakePreferences) {
        autoOff = preferences.autoOff
        deactivationDate = autoOff.duration.map { Date(timeIntervalSinceNow: $0) }

        if !preferences.keepsAwakeWithLidClosed {
            assertion = PowerAssertion(type: kIOPMAssertionTypePreventUserIdleSystemSleep as String)
            lidClosedSleepWatchdog = nil
            return
        }

        let watchdog = launchLidClosedSleepWatchdog()
        let didDisableSleep = setLidClosedSleepDisabled(true)
        if !didDisableSleep {
            watchdog.terminate()
            return nil
        }

        assertion = PowerAssertion(type: kIOPMAssertionTypePreventUserIdleDisplaySleep as String)
        lidClosedSleepWatchdog = watchdog
    }

    func end() -> Bool {
        if let lidClosedSleepWatchdog {
            let didRestoreSleep = setLidClosedSleepDisabled(false)
            if !didRestoreSleep { return false }
            lidClosedSleepWatchdog.terminate()
        }

        assertion.release()
        return true
    }
}
