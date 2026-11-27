import Foundation
@testable import MacUtilities

/// Preferences in a defaults domain of their own whose stored values are only registered, so nothing is written to disk.
func buildPreferences(disabledFeatures: [String]) -> Preferences {
    let defaults = UserDefaults(suiteName: "MacUtilitiesTests.\(UUID().uuidString)")!

    defaults.register(defaults: ["disabledFeatures": disabledFeatures])

    return Preferences(defaults: defaults)
}
