import Foundation

/// Whether the app runs from an Applications folder, where install.sh puts it, rather than from a development build's folder. Symlinks are
/// resolved on both sides, so a symlinked ~/Applications or a bundle reached through a symlink still counts.
func isInApplicationsFolder(bundleURL: URL) -> Bool {
    let applicationsFolders = FileManager.default.urls(for: .applicationDirectory, in: [.userDomainMask, .localDomainMask])
    let resolvedApplicationsFolders = applicationsFolders.map { $0.resolvingSymlinksInPath().path }
    return resolvedApplicationsFolders.contains(bundleURL.deletingLastPathComponent().resolvingSymlinksInPath().path)
}
