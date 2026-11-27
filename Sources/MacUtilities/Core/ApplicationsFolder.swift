import Foundation

/// Whether the app runs from an Applications folder, where install.sh puts it, rather than from a development build's folder. Symlinks are
/// resolved on both sides, so a symlinked ~/Applications, a symlinked folder on the way to the bundle or a symlink to the bundle itself
/// still counts.
func isInApplicationsFolder(bundleURL: URL) -> Bool {
    let applicationsFolders = FileManager.default.urls(for: .applicationDirectory, in: [.userDomainMask, .localDomainMask])
    let resolvedApplicationsFolders = applicationsFolders.map { $0.resolvingSymlinksInPath().path }
    return resolvedApplicationsFolders.contains(bundleURL.resolvingSymlinksInPath().deletingLastPathComponent().path)
}
