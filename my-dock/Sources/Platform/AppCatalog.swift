import AppKit

let finderPath = "/System/Library/CoreServices/Finder.app"
let myDockBundleID = "com.ulvifk.my-dock"

enum AppCatalog {
    static func resolveApplication(_ url: URL, isKept: Bool) -> SavedApp? {
        if !url.isFileURL { return nil }
        let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL
        if resolvedURL.pathExtension.lowercased() != "app" { return nil }
        guard let bundle = Bundle(url: resolvedURL) else { return nil }
        guard let id = bundle.bundleIdentifier else { return nil }
        if id == myDockBundleID { return nil }
        let name = FileManager.default.displayName(atPath: resolvedURL.path)
        return SavedApp(id: id, url: resolvedURL, name: name, isKept: isKept)
    }

    static func getRunningApplications() -> [NSRunningApplication] {
        return NSWorkspace.shared.runningApplications.filter { isRegularApplication($0) }
    }

    static func getRunningApps(_ applications: [NSRunningApplication]) -> [SavedApp] {
        return applications.compactMap { application in
            guard let url = application.bundleURL else { return nil }
            return resolveApplication(url, isKept: false)
        }
    }

    static func importDockPins() -> [SavedApp] {
        let defaults = UserDefaults(suiteName: "com.apple.dock")!
        let tiles = defaults.array(forKey: "persistent-apps") as? [[String: Any]] ?? []
        var apps = [resolveApplication(URL(fileURLWithPath: finderPath), isKept: true)!]
        var ids = Set(apps.map(\.id))
        for tile in tiles {
            guard let data = tile["tile-data"] as? [String: Any] else { continue }
            guard let file = data["file-data"] as? [String: Any] else { continue }
            guard let path = file["_CFURLString"] as? String else { continue }
            guard let url = URL(string: path) else { continue }
            guard let app = resolveApplication(url, isKept: true) else { continue }
            if !ids.insert(app.id).inserted { continue }
            apps.append(app)
        }
        return apps
    }

    private static func isRegularApplication(_ app: NSRunningApplication) -> Bool {
        if app.activationPolicy != .regular { return false }
        if app.isTerminated { return false }
        if app.bundleIdentifier == myDockBundleID { return false }
        return true
    }
}
