import Foundation

/// Which features run, in UserDefaults. Every feature is enabled until switched off.
final class Preferences {
    private let enabledFeaturesKey = "enabledFeatures"
    private let defaults = UserDefaults.standard

    init(featureIdentifiers: [String]) {
        defaults.register(defaults: [enabledFeaturesKey: featureIdentifiers])
    }

    func isFeatureEnabled(_ identifier: String) -> Bool {
        return getEnabledFeatures().contains(identifier)
    }

    func setFeatureEnabled(_ identifier: String, _ enabled: Bool) {
        var enabledFeatures = getEnabledFeatures()

        if enabled {
            enabledFeatures.insert(identifier)
        } else {
            enabledFeatures.remove(identifier)
        }

        defaults.set(Array(enabledFeatures), forKey: enabledFeaturesKey)
    }

    private func getEnabledFeatures() -> Set<String> {
        return Set(defaults.stringArray(forKey: enabledFeaturesKey)!)
    }
}
