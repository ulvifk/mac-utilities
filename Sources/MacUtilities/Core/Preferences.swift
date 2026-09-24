import Foundation

/// Which features are switched off, in UserDefaults. A feature the store has never heard of runs, so new features start enabled.
final class Preferences {
    private let disabledFeaturesKey = "disabledFeatures"
    private let defaults = UserDefaults.standard

    func isFeatureEnabled(_ identifier: String) -> Bool {
        return !getDisabledFeatures().contains(identifier)
    }

    func setFeatureEnabled(_ identifier: String, _ enabled: Bool) {
        var disabledFeatures = getDisabledFeatures()

        if enabled {
            disabledFeatures.remove(identifier)
        } else {
            disabledFeatures.insert(identifier)
        }

        defaults.set(Array(disabledFeatures), forKey: disabledFeaturesKey)
    }

    private func getDisabledFeatures() -> Set<String> {
        return Set(defaults.stringArray(forKey: disabledFeaturesKey) ?? [])
    }
}
