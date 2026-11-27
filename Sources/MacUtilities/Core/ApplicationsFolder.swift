import Foundation

/// Whether the app runs from an Applications folder, where install.sh puts it, rather than from a development build's folder.
func isInApplicationsFolder(bundleURL: URL) -> Bool {
    let applicationsFolders = FileManager.default.urls(for: .applicationDirectory, in: [.userDomainMask, .localDomainMask])
    return applicationsFolders.map(\.path).contains(bundleURL.deletingLastPathComponent().path)
}
