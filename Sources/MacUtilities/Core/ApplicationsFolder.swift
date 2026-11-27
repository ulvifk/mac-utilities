import Foundation

/// Whether the bundle sits directly in one of the Applications folders, where install.sh puts it, rather than in a development build's
/// folder. Symlinks are resolved on both sides, so a symlinked Applications folder, a symlinked folder on the way to the bundle or a symlink
/// to the bundle itself still counts; an entry in an Applications folder that links to a bundle elsewhere does not.
func isInApplicationsFolder(bundleURL: URL, applicationsFolders: [URL]) -> Bool {
    let resolvedApplicationsFolders = applicationsFolders.map { $0.resolvingSymlinksInPath().path }
    return resolvedApplicationsFolders.contains(bundleURL.resolvingSymlinksInPath().deletingLastPathComponent().path)
}
