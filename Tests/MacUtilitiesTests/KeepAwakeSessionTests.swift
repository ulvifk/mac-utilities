import IOKit.pwr_mgt
import Testing
@testable import MacUtilities

@MainActor
struct KeepAwakeSessionTests {
    @Test
    func failedRestorationKeepsAssertionAndWatchdogUntilRetrySucceeds() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        let session = harness.buildSession()
        let begin = Task { await session.begin() }
        try await harness.completeCommand(disabled: true)
        #expect(try await waitForResult(of: begin), "Session activation failed")

        let failure = Task { await session.end() }
        try await harness.completeCommand(disabled: false, succeeds: false)
        #expect(!(try await waitForResult(of: failure)), "Failed restoration must report failure")
        #expect(power.assertionReleaseCount == 0, "Failed restoration released the assertion")
        #expect(power.watchdogTerminationCount == 0, "Failed restoration stopped the watchdog")

        let retry = Task { await session.end() }
        try await harness.completeCommand(disabled: false)
        #expect(try await waitForResult(of: retry), "The next restoration should succeed")
        #expect(power.assertionReleaseCount == 1, "Successful restoration did not release the assertion once")
        #expect(power.watchdogTerminationCount == 1, "Successful restoration did not stop the watchdog once")
    }

    @Test
    func idleSleepSessionHoldsOnlyAnAssertion() async {
        let harness = KeepAwakeHarness()
        let power = harness.power
        harness.preferences.setKeepsAwakeWithLidClosed(false)
        let session = harness.buildSession()

        #expect(await session.begin(), "An idle-sleep session should activate")
        #expect(Array(power.heldAssertionTypes.values) == [kIOPMAssertionTypePreventUserIdleSystemSleep as String])
        #expect(await session.end(), "An idle-sleep session should end successfully")
        #expect(power.commandHistory.isEmpty, "An idle-sleep session changed lid sleep")
        #expect(power.watchdogLaunchCount == 0, "An idle-sleep session launched a watchdog")
        #expect(power.assertionReleaseCount == 1, "An idle-sleep session did not release its assertion")
    }
}
