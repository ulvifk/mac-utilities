import Foundation

/// A defaults domain of its own for one test, so no test touches the app's real preferences.
final class KeepAwakeTestDefaults {
    let domain = "com.ulvifk.mac-utilities.tests.\(UUID().uuidString)"

    /// A new UserDefaults instance on the domain each call, as each launch of the app has its own.
    func buildUserDefaults() -> UserDefaults {
        return UserDefaults(suiteName: domain)!
    }

    /// Removes the domain, and the empty plist cfprefsd leaves behind for a domain that was written to.
    func remove() {
        buildUserDefaults().removePersistentDomain(forName: domain)

        let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/\(domain).plist")
        if !FileManager.default.fileExists(atPath: file.path) { return }
        try! FileManager.default.removeItem(at: file)
    }
}
