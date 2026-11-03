import AppKit

/// Bundle identifiers of the apps activated since start, the frontmost one at start included; front of the array is the most recent.
/// Apps that quit stay listed, as the switcher only reads the ones still running.
final class RecentAppsTracker {
    private(set) var bundleIdentifiers: [String] = []
    private var observer: NSObjectProtocol?

    func start() {
        if let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
            moveToFront(frontmost)
        }

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let bundleIdentifier = app?.bundleIdentifier else { return }
            self.moveToFront(bundleIdentifier)
        }
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(observer!)
        observer = nil
    }

    func moveToFront(_ bundleIdentifier: String) {
        bundleIdentifiers.removeAll { $0 == bundleIdentifier }
        bundleIdentifiers.insert(bundleIdentifier, at: 0)
    }
}
