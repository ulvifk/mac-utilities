import Foundation
import Testing
@testable import MacUtilities

/// Each test reads back through a second KeepAwakePreferences on its own UserDefaults instance, as the next launch would, and from the plist
/// on disk under the key the app has always used.
struct KeepAwakePreferencesTests {
    private let powerOnlyKey = "keepAwakeOnlyWhileConnectedToPower"

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
            #expect(defaults.readStoredValues()[powerOnlyKey] as? Bool == true, "The enabled power option did not reach the disk")
        }
    }

    @Test
    func disabledPowerOptionIsLoadedByTheNextLaunch() {
        withTestDefaults { defaults in
            buildPreferences(defaults).setOnlyWhileConnectedToPower(true)
            buildPreferences(defaults).setOnlyWhileConnectedToPower(false)

            #expect(!buildPreferences(defaults).onlyWhileConnectedToPower, "A new launch did not load the disabled power option")
            #expect(defaults.readStoredValues()[powerOnlyKey] as? Bool == false, "The disabled power option did not reach the disk")
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
