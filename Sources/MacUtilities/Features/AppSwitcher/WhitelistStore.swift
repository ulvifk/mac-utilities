import Foundation

/// The filter switch and the whitelisted bundle identifiers, in UserDefaults.
final class WhitelistStore {
    private let filterEnabledKey = "filterEnabled"
    private let whitelistKey = "whitelist"
    private let defaults = UserDefaults.standard

    var isFilterEnabled: Bool {
        return defaults.bool(forKey: filterEnabledKey)
    }

    func setFilterEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: filterEnabledKey)
    }

    func getWhitelist() -> Set<String> {
        return Set(defaults.stringArray(forKey: whitelistKey) ?? [])
    }

    func toggleWhitelist(bundleIdentifier: String) {
        var whitelist = getWhitelist()

        if whitelist.contains(bundleIdentifier) {
            whitelist.remove(bundleIdentifier)
        } else {
            whitelist.insert(bundleIdentifier)
        }

        defaults.set(Array(whitelist), forKey: whitelistKey)
    }
}
