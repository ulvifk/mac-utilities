import Combine
import Foundation

/// The filter switch and the whitelisted bundle identifiers, in UserDefaults. Publishes every change, so the settings tab follows the in-switcher shortcuts.
final class WhitelistStore: AppListStore {
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

    func isListed(_ bundleIdentifier: String) -> Bool {
        return getWhitelist().contains(bundleIdentifier)
    }

    func setListed(_ bundleIdentifier: String, _ listed: Bool) {
        var whitelist = getWhitelist()

        if listed {
            whitelist.insert(bundleIdentifier)
        } else {
            whitelist.remove(bundleIdentifier)
        }

        objectWillChange.send()
        defaults.set(Array(whitelist), forKey: whitelistKey)
    }
}
