import Testing
@testable import MacUtilities

/// Sleeping the Mac by macOS's own clamshell verdict once a session stops holding a closed lid awake.
@MainActor
struct KeepAwakeClosedLidTests {
    @Test(arguments: [true, false])
    func turningOffSleepsTheMacOnlyWhenMacOSSaysAClosedLidSleeps(closedLidCausesSleep: Bool) async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        power.closedLidCausesSleep = closedLidCausesSleep
        let feature = harness.buildFeature()
        try await harness.activate(feature)
        #expect(power.sleepCount == 0, "Turning on slept the Mac")

        feature.toggle(from: .popoverToggle)
        try await harness.completeCommand(disabled: false)
        try await waitUntil { !feature.isChangingSession }
        #expect(power.sleepCount == (closedLidCausesSleep ? 1 : 0), closedLidCausesSleep ? "Turning off left a closed lid awake" : "Turning off slept a Mac that macOS keeps awake")
    }

    @Test
    func unpluggingSleepsAClosedLid() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        power.closedLidCausesSleep = true
        harness.preferences.setOnlyWhileConnectedToPower(true)
        let feature = harness.buildFeature()
        try await harness.activate(feature)

        try power.setExternalPowerConnected(false)
        try await harness.completeCommand(disabled: false)
        try await waitUntil { !feature.isChangingSession }
        #expect(power.sleepCount == 1, "Unplugging left a closed lid awake")
    }

    @Test
    func expiringSleepsAClosedLid() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        power.closedLidCausesSleep = true
        harness.preferences.setAutoOff(.thirtyMinutes)
        let feature = harness.buildFeature()
        try await harness.activate(feature)

        harness.clock.advance(by: 30 * 60)
        try await harness.completeCommand(disabled: false)
        try await waitUntil { !feature.isChangingSession }
        #expect(power.sleepCount == 1, "Expiring left a closed lid awake")
    }

    @Test
    func closedLidSleepsOnlyOnceRestorationSucceeds() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        power.closedLidCausesSleep = true
        let feature = harness.buildFeature()
        try await harness.activate(feature)

        feature.toggle(from: .popoverToggle)
        try await harness.completeCommand(disabled: false, succeeds: false)
        try await waitUntil { !feature.isChangingSession }
        #expect(power.sleepCount == 0, "A failed restoration slept the Mac with sleep still disabled")

        feature.toggle(from: .popoverToggle)
        try await harness.completeCommand(disabled: false)
        try await waitUntil { !feature.isChangingSession }
        #expect(power.sleepCount == 1, "A successful retry left a closed lid awake")
    }

    @Test(arguments: [true, false])
    func replacementSleepsAClosedLidOnlyWhenItDoesNotKeepTheLidAwake(keepsLidAwake: Bool) async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        power.closedLidCausesSleep = true
        let feature = harness.buildFeature()
        try await harness.activate(feature)

        harness.preferences.setKeepsAwakeWithLidClosed(keepsLidAwake)
        feature.turnOn(for: .oneHour)
        try await harness.completeCommand(disabled: false)
        if keepsLidAwake { try await harness.completeCommand(disabled: true) }
        try await waitUntil { !feature.isChangingSession }
        #expect(feature.session?.autoOff == .oneHour, "The replacement session did not begin")
        #expect(power.sleepCount == (keepsLidAwake ? 0 : 1), keepsLidAwake ? "A replacement that keeps the lid awake slept the Mac" : "A replacement without the lid option left a closed lid awake")
    }

    @Test
    func endingAnIdleSleepSessionDoesNotSleepAClosedLid() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        power.closedLidCausesSleep = true
        harness.preferences.setKeepsAwakeWithLidClosed(false)
        let feature = harness.buildFeature()

        feature.toggle(from: .popoverToggle)
        try await waitUntil { feature.session != nil }
        feature.toggle(from: .popoverToggle)
        try await waitUntil { feature.session == nil && !feature.isChangingSession }
        #expect(power.sleepCount == 0, "Ending a session that never held the lid awake slept the Mac")
    }

    /// Follows AppController: stop on Quit, then cleanup in a Task once the earlier features finished theirs, which here outlast the restore.
    @Test
    func quitRestoresSleepWithoutSleepingAClosedLid() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        power.closedLidCausesSleep = true
        let feature = harness.buildFeature()
        try await harness.activate(feature)

        feature.stop(because: .quit)
        try await harness.completeCommand(disabled: false)
        try await waitUntil { !feature.isChangingSession }
        #expect(feature.session == nil, "Quit did not restore sleep")
        #expect(power.sleepCount == 0, "Quit slept the Mac before its cleanup began")

        try await waitForResult(of: Task { await feature.prepareForTermination() })
        #expect(power.sleepCount == 0, "Quit slept the Mac")
    }

    /// A feature switched off earlier is never stopped on Quit, but its retried restoration still finishes in its cleanup.
    @Test
    func quitAfterSwitchingOffRestoresSleepWithoutSleepingAClosedLid() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        power.closedLidCausesSleep = true
        let feature = harness.buildFeature()
        try await harness.activate(feature)
        feature.stop(because: .switchedOff)
        try await harness.completeCommand(disabled: false, succeeds: false)
        try await waitUntil { !feature.isChangingSession }

        let termination = Task { await feature.prepareForTermination() }
        try await harness.completeCommand(disabled: false)
        try await waitForResult(of: termination)
        #expect(feature.session == nil, "Quit did not finish the switched-off feature's restoration")
        #expect(power.sleepCount == 0, "Quit slept the Mac")
    }
}
