import Foundation
import IOKit.pwr_mgt
@testable import MacUtilities

/// Records what Keep Awake asks of macOS. Lid-closed sleep commands stay pending until the test completes them, in order.
final class FakePowerManagement: PowerManagement {
    var closedLidCausesSleep = false
    private(set) var isExternalPowerConnected = true
    private var onExternalPowerChange: (() -> Void)?

    private(set) var commandHistory: [Bool] = [] // the disabled argument of every pmset command, in order
    private(set) var pendingCommands: [(disabled: Bool, continuation: CheckedContinuation<Bool, Never>)] = []

    private(set) var heldAssertionTypes: [IOPMAssertionID: String] = [:]
    private(set) var assertionReleaseCount = 0
    private var nextAssertionID = IOPMAssertionID(1)

    private(set) var watchdogLaunchCount = 0
    private(set) var watchdogTerminationCount = 0
    private(set) var sleepCount = 0

    func createAssertion(type: String) -> IOPMAssertionID {
        let id = nextAssertionID
        nextAssertionID += 1
        heldAssertionTypes[id] = type
        return id
    }

    func releaseAssertion(_ id: IOPMAssertionID) {
        heldAssertionTypes[id] = nil
        assertionReleaseCount += 1
    }

    @MainActor func setLidClosedSleepDisabled(_ disabled: Bool) async -> Bool {
        commandHistory.append(disabled)
        return await withCheckedContinuation { continuation in
            pendingCommands.append((disabled, continuation))
        }
    }

    @MainActor func completeOldestCommand(succeeds: Bool) {
        pendingCommands.removeFirst().continuation.resume(returning: succeeds)
    }

    /// An unlaunched process: only its identity matters to the session.
    func launchLidClosedSleepWatchdog() -> Process {
        watchdogLaunchCount += 1
        return Process()
    }

    func terminateLidClosedSleepWatchdog(_ watchdog: Process) {
        watchdogTerminationCount += 1
    }

    func isClosedLidCausingSleep() -> Bool {
        return closedLidCausesSleep
    }

    func sleepMac() {
        sleepCount += 1
    }

    func isConnectedToExternalPower() -> Bool {
        return isExternalPowerConnected
    }

    func startObservingExternalPower(_ onChange: @escaping () -> Void) {
        onExternalPowerChange = onChange
    }

    /// Plugs or unplugs external power and notifies the observer, as the IOKit run loop source does.
    func setExternalPowerConnected(_ connected: Bool) {
        isExternalPowerConnected = connected
        onExternalPowerChange!()
    }
}
