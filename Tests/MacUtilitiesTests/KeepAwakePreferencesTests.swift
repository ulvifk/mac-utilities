import Foundation
import Testing
@testable import MacUtilities

/// Each test reads back through a second KeepAwakePreferences on its own UserDefaults instance, as the next launch would.
struct KeepAwakePreferencesTests {
    @Test
    func powerOptionDefaultsToOff() {
        withTestDefaults { defaults in
            #expect(!buildPreferences(defaults).onlyWhileConnectedToPower, "The power option must default to off")
        }
    }

    @Test
    func enabledPowerOptionIsLoadedByTheNextLaunch() {
        withTestDefaults { defaults in
            buildPreferences(defaults).setOnlyWhileConnectedToPower(true)

            #expect(buildPreferences(defaults).onlyWhileConnectedToPower, "A new launch did not load the enabled power option")
        }
    }

    @Test
    func disabledPowerOptionIsLoadedByTheNextLaunch() {
        withTestDefaults { defaults in
            buildPreferences(defaults).setOnlyWhileConnectedToPower(true)
            buildPreferences(defaults).setOnlyWhileConnectedToPower(false)

            #expect(!buildPreferences(defaults).onlyWhileConnectedToPower, "A new launch did not load the disabled power option")
        }
    }

    private func buildPreferences(_ defaults: TestDefaults) -> KeepAwakePreferences {
        return KeepAwakePreferences(defaults: defaults.buildUserDefaults())
    }

    private func withTestDefaults(_ body: (TestDefaults) -> Void) {
        let defaults = TestDefaults()
        defer { defaults.remove() }
        body(defaults)
    }
}
