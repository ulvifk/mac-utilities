import AppKit

/// Process identifiers of the processes active since the last start: the frontmost one at start, then each one activated since; front of the
/// array is the most recent. A process leaves when it quits, and each start begins anew, as quits went unheard while stopped; so a later
/// process that reuses an identifier starts untracked.
final class RecentAppsTracker {
    private(set) var processIdentifiers: [pid_t] = []
    private var observers: [NSObjectProtocol] = []

    func start() {
        let notificationCenter = NSWorkspace.shared.notificationCenter

        processIdentifiers = []
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            moveToFront(frontmost.processIdentifier)
        }
        observers.append(notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { notification in
            self.moveToFront(Self.getProcessIdentifier(notification))
        })
        observers.append(notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { notification in
            self.forget(Self.getProcessIdentifier(notification))
        })
    }

    func stop() {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers = []
    }

    private func moveToFront(_ processIdentifier: pid_t) {
        forget(processIdentifier)
        processIdentifiers.insert(processIdentifier, at: 0)
    }

    private func forget(_ processIdentifier: pid_t) {
        processIdentifiers.removeAll { $0 == processIdentifier }
    }

    /// Of the app a workspace notification is about.
    private static func getProcessIdentifier(_ notification: Notification) -> pid_t {
        let app = notification.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
        return app.processIdentifier
    }
}
