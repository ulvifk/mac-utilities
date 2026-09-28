import Combine
import Foundation

/// The bundle identifiers on the Batch Quit list, in UserDefaults, so an app stays on it while it is not running. Publishes every change to the
/// settings tab.
final class BatchQuitStore: ObservableObject {
    private let batchQuitListKey = "batchQuitList"
    private let defaults = UserDefaults.standard

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

    private func getBatchQuitList() -> Set<String> {
        return Set(defaults.stringArray(forKey: batchQuitListKey) ?? [])
    }
}
