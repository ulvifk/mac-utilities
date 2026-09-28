import Combine
import Foundation

/// The bundle identifiers on the Batch Quit list, in UserDefaults, so an app stays on it while it is not running, and whether Batch Quit quits
/// the listed apps or the others. Publishes every change to the settings tab.
final class BatchQuitStore: AppListStore {
    private let batchQuitListKey = "batchQuitList"
    private let quitsUnlistedAppsKey = "batchQuitUnlistedApps"
    private let defaults = UserDefaults.standard

    /// Quit the apps off the list and keep the listed ones, rather than the other way round.
    var quitsUnlistedApps: Bool {
        return defaults.bool(forKey: quitsUnlistedAppsKey)
    }

    func setQuitsUnlistedApps(_ quitsUnlistedApps: Bool) {
        objectWillChange.send()
        defaults.set(quitsUnlistedApps, forKey: quitsUnlistedAppsKey)
    }

    func isListed(_ bundleIdentifier: String) -> Bool {
        return getBatchQuitList().contains(bundleIdentifier)
    }

    func setListed(_ bundleIdentifier: String, _ listed: Bool) {
        var batchQuitList = getBatchQuitList()

        if listed {
            batchQuitList.insert(bundleIdentifier)
        } else {
            batchQuitList.remove(bundleIdentifier)
        }

        objectWillChange.send()
        defaults.set(Array(batchQuitList), forKey: batchQuitListKey)
    }

    /// Listed, or unlisted while the unlisted apps are the ones quit.
    func isBatchQuitTarget(_ bundleIdentifier: String) -> Bool {
        if quitsUnlistedApps { return !isListed(bundleIdentifier) }
        return isListed(bundleIdentifier)
    }

    private func getBatchQuitList() -> Set<String> {
        return Set(defaults.stringArray(forKey: batchQuitListKey) ?? [])
    }
}
