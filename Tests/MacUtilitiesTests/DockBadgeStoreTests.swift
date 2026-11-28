import Foundation
import Testing
@testable import MacUtilities

/// The Dock badges switch: on until it is turned off, and kept for the next launch.
final class DockBadgeStoreTests {
    private let defaults = TestDefaults()

    deinit {
        defaults.remove()
    }

    @Test
    func showsBadgesUntilTurnedOff() {
        #expect(DockBadgeStore(defaults: defaults.buildUserDefaults()).showsBadges)
    }

    @Test(arguments: [false, true])
    func switchIsStoredForTheNextLaunch(showsBadges: Bool) throws {
        DockBadgeStore(defaults: defaults.buildUserDefaults()).setShowsBadges(showsBadges)

        #expect(try defaults.readStoredValues()["dockBadges"] as? Bool == showsBadges)
        #expect(DockBadgeStore(defaults: defaults.buildUserDefaults()).showsBadges == showsBadges)
    }
}
