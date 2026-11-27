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

        feature.toggle()
        try await harness.completeCommand(disabled: false)
        try await harness.waitUntil { !feature.isChangingSession }
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

        power.setExternalPowerConnected(false)
        try await harness.completeCommand(disabled: false)
        try await harness.waitUntil { !feature.isChangingSession }
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
        try await harness.waitUntil { !feature.isChangingSession }
        #expect(power.sleepCount == 1, "Expiring left a closed lid awake")
    }

    @Test
    func closedLidSleepsOnlyOnceRestorationSucceeds() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        power.closedLidCausesSleep = true
        let feature = harness.buildFeature()
        try await harness.activate(feature)

        feature.toggle()
        try await harness.completeCommand(disabled: false, succeeds: false)
        try await harness.waitUntil { !feature.isChangingSession }
        #expect(power.sleepCount == 0, "A failed restoration slept the Mac with sleep still disabled")

        feature.toggle()
        try await harness.completeCommand(disabled: false)
        try await harness.waitUntil { !feature.isChangingSession }
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
        try await harness.waitUntil { !feature.isChangingSession }
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

        feature.toggle()
        try await harness.waitUntil { feature.session != nil }
        feature.toggle()
        try await harness.waitUntil { feature.session == nil && !feature.isChangingSession }
        #expect(power.sleepCount == 0, "Ending a session that never held the lid awake slept the Mac")
    }

    @Test
    func quitRestoresSleepWithoutSleepingAClosedLid() async throws {
        let harness = KeepAwakeHarness()
        let power = harness.power
        power.closedLidCausesSleep = true
        let feature = harness.buildFeature()
        try await harness.activate(feature)

        let termination = Task { await feature.prepareForTermination() }
        try await harness.completeCommand(disabled: false)
        await termination.value
        #expect(feature.session == nil, "Termination did not restore sleep")
        #expect(power.sleepCount == 0, "Termination slept the Mac")
    }
}
