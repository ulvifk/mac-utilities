import AppKit

private let applicationDirectories = [
    "/Applications",
    "/Applications/Utilities",
    "/System/Applications",
    "/System/Applications/Utilities",
    NSHomeDirectory() + "/Applications",
]

struct InstalledApp {
    let bundleIdentifier: String
    let name: String
    let icon: NSImage
}

/// The .app bundles in the usual application folders, by name, one per bundle identifier.
func getInstalledApps() -> [InstalledApp] {
    var appsByIdentifier: [String: InstalledApp] = [:]

    for directory in applicationDirectories {
        for app in getInstalledApps(in: directory) {
            if appsByIdentifier[app.bundleIdentifier] != nil { continue }
            appsByIdentifier[app.bundleIdentifier] = app
        }
    }

    return appsByIdentifier.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

private func getInstalledApps(in directory: String) -> [InstalledApp] {
    guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return [] }

    var apps: [InstalledApp] = []
    for entry in entries {
        if !entry.hasSuffix(".app") { continue }

        let path = directory + "/" + entry
        guard let bundleIdentifier = Bundle(path: path)?.bundleIdentifier else { continue }

        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 16, height: 16)
        apps.append(InstalledApp(bundleIdentifier: bundleIdentifier, name: String(entry.dropLast(".app".count)), icon: icon))
    }

    return apps
}

/// The apps whose name contains the search text anywhere, ignoring case, in their given order; all of them while the search text is empty.
/// e.g. "code" over [Xcode, Visual Studio Code, Safari] -> [Xcode, Visual Studio Code]
func getApps(in apps: [InstalledApp], withNameContaining searchText: String) -> [InstalledApp] {
    if searchText.isEmpty { return apps }

    return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
}
