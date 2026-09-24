import Combine
import Foundation

/// The filter switch and the whitelisted bundle identifiers, in UserDefaults. Publishes every change, so the settings tab follows the in-switcher shortcuts.
final class WhitelistStore: ObservableObject {
    private let filterEnabledKey = "filterEnabled"
    private let whitelistKey = "whitelist"
    private let defaults = UserDefaults.standard

    var isFilterEnabled: Bool {
        return defaults.bool(forKey: filterEnabledKey)
    }

    func setFilterEnabled(_ enabled: Bool) {
        objectWillChange.send()
        defaults.set(enabled, forKey: filterEnabledKey)
    }

    func getWhitelist() -> Set<String> {
        return Set(defaults.stringArray(forKey: whitelistKey) ?? [])
    }

    func isWhitelisted(_ bundleIdentifier: String) -> Bool {
        return getWhitelist().contains(bundleIdentifier)
    }

    func setWhitelisted(_ bundleIdentifier: String, _ whitelisted: Bool) {
        var whitelist = getWhitelist()

        if whitelisted {
            whitelist.insert(bundleIdentifier)
        } else {
            whitelist.remove(bundleIdentifier)
        }

        objectWillChange.send()
        defaults.set(Array(whitelist), forKey: whitelistKey)
    }
}
