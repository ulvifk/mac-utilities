import Foundation

/// A defaults domain of its own for one test, so no test touches the app's real preferences. The domain is a plist in a temporary directory
/// rather than a name: a named domain leaves an empty plist in ~/Library/Preferences that cfprefsd writes whenever it gets to it, which no
/// cleanup can reliably wait for.
final class TestDefaults {
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mac-utilities-tests-\(UUID().uuidString)")

    init() {
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// A new UserDefaults instance on the domain each call, as each launch of the app has its own.
    func buildUserDefaults() -> UserDefaults {
        return UserDefaults(suiteName: directory.appendingPathComponent("preferences").path)!
    }

    /// What the domain holds on disk, which is what the next launch of the app would load.
    func readStoredValues() -> [String: Any] {
        buildUserDefaults().synchronize()
        return NSDictionary(contentsOf: directory.appendingPathComponent("preferences.plist")) as! [String: Any]
    }

    func remove() {
        try! FileManager.default.removeItem(at: directory)
    }
}
