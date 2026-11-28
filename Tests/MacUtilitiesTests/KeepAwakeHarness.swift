import Foundation
import Testing
@testable import MacUtilities

/// One Keep Awake feature on fakes, with preferences in a throwaway defaults domain that is removed when the harness goes away.
@MainActor
final class KeepAwakeHarness {
    let power = FakePowerManagement()
    let clock = FakeWallClock()
    let preferences: KeepAwakePreferences
    private(set) var menuBarSymbol: String?
    private(set) var menuBarSymbolChangeCount = 0

    private let defaults = TestDefaults()

    init() {
        preferences = KeepAwakePreferences(defaults: defaults.buildUserDefaults())
    }

    deinit {
        defaults.remove()
    }

    func buildFeature() -> KeepAwakeFeature {
        return KeepAwakeFeature(preferences: preferences, powerManagement: power, clock: clock, setMenuBarSymbol: { symbol in
            #expect(Thread.isMainThread, "The menu bar icon changed off the main thread")
            self.menuBarSymbol = symbol
            self.menuBarSymbolChangeCount += 1
        })
    }

    func buildSession() -> KeepAwakeSession {
        return KeepAwakeSession(
            autoOff: .untilTurnedOff,
            deactivationDate: nil,
            keepsAwakeWithLidClosed: preferences.keepsAwakeWithLidClosed,
            powerManagement: power
        )
    }

    /// Waits for the oldest pmset command, which must be the given one, and completes it.
    func completeCommand(disabled: Bool, succeeds: Bool = true, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await waitUntil({ !power.pendingCommands.isEmpty }, sourceLocation: sourceLocation)
        try #require(power.pendingCommands[0].disabled == disabled, "Power commands ran out of order", sourceLocation: sourceLocation)
        power.completeOldestCommand(succeeds: succeeds)
    }

    /// Turns the feature on with the toggle and completes the lid command.
    func activate(_ feature: KeepAwakeFeature, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        feature.toggle(from: .popoverToggle)
        try await completeCommand(disabled: true, sourceLocation: sourceLocation)
        try await waitUntil({ !feature.isChangingSession }, sourceLocation: sourceLocation)
        try #require(feature.session != nil, "Successful activation did not publish a session", sourceLocation: sourceLocation)
    }
}
