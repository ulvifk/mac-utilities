import Foundation

/// The app's own state in UserDefaults: which features are switched off, and whether the installed app has launched before. A feature the
/// store has never heard of runs, so new features start enabled.
final class Preferences {
    private let disabledFeaturesKey = "disabledFeatures"
    private let hasLaunchedKey = "hasLaunched"

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

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

    func isFirstLaunch() -> Bool {
        return !defaults.bool(forKey: hasLaunchedKey)
    }

    func recordFirstLaunch() {
        defaults.set(true, forKey: hasLaunchedKey)
    }

    private func getDisabledFeatures() -> Set<String> {
        return Set(defaults.stringArray(forKey: disabledFeaturesKey) ?? [])
    }
}
