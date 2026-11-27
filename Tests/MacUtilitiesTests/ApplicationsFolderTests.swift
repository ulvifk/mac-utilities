import Foundation
import Testing
@testable import MacUtilities

/// Which bundles count as installed, on a layout built in a temporary directory that stands in for the Applications folder, so nothing reads
/// the Mac's own folders:
///
/// - Applications/MacUtilities.app, a bundle
/// - Applications/Subfolder/MacUtilities.app, a bundle one level too deep
/// - Applications/Linked.app -> Elsewhere/MacUtilities.app
/// - Elsewhere/MacUtilities.app, a bundle in another folder
/// - ApplicationsLink -> Applications
/// - BundleLink.app -> Applications/MacUtilities.app
final class ApplicationsFolderTests {
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mac-utilities-tests-\(UUID().uuidString)")
    private let applications: URL
    private let applicationsLink: URL
    private let installedBundle: URL
    private let bundleElsewhere: URL

    init() {
        applications = directory.appendingPathComponent("Applications", isDirectory: true)
        applicationsLink = directory.appendingPathComponent("ApplicationsLink", isDirectory: true)
        installedBundle = applications.appendingPathComponent("MacUtilities.app", isDirectory: true)
        bundleElsewhere = directory.appendingPathComponent("Elsewhere/MacUtilities.app", isDirectory: true)

        try! FileManager.default.createDirectory(at: installedBundle, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(at: applications.appendingPathComponent("Subfolder/MacUtilities.app"), withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(at: bundleElsewhere, withIntermediateDirectories: true)
        try! FileManager.default.createSymbolicLink(at: applications.appendingPathComponent("Linked.app"), withDestinationURL: bundleElsewhere)
        try! FileManager.default.createSymbolicLink(at: applicationsLink, withDestinationURL: applications)
        try! FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("BundleLink.app"), withDestinationURL: installedBundle)
    }

    deinit {
        try! FileManager.default.removeItem(at: directory)
    }

    @Test
    func bundleInTheApplicationsFolderCounts() {
        #expect(isInstalled(installedBundle))
    }

    @Test
    func symlinkedFolderOnTheWayToTheBundleCounts() {
        #expect(isInstalled(applicationsLink.appendingPathComponent("MacUtilities.app", isDirectory: true)))
    }

    @Test
    func symlinkToTheBundleItselfCounts() {
        #expect(isInstalled(directory.appendingPathComponent("BundleLink.app")))
    }

    @Test
    func symlinkedApplicationsFolderCounts() {
        #expect(isInApplicationsFolder(bundleURL: installedBundle, applicationsFolders: [applicationsLink]))
    }

    @Test
    func bundleInASubfolderDoesNotCount() {
        #expect(!isInstalled(applications.appendingPathComponent("Subfolder/MacUtilities.app", isDirectory: true)))
    }

    /// Such as the repository folder build.sh puts the development build in, or an AppTranslocation folder.
    @Test
    func bundleInAnotherFolderDoesNotCount() {
        #expect(!isInstalled(bundleElsewhere))
    }

    @Test
    func entryLinkingToABundleElsewhereDoesNotCount() {
        #expect(!isInstalled(applications.appendingPathComponent("Linked.app")))
    }

    private func isInstalled(_ bundleURL: URL) -> Bool {
        return isInApplicationsFolder(bundleURL: bundleURL, applicationsFolders: [applications])
    }
}
