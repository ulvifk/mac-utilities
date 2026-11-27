import AppKit
import Testing
@testable import MacUtilities

/// SystemSwitcherWorkspace hears the workspace's activate, quit, hide and unhide notifications, reading the app from the notification. They
/// are posted to this process's own workspace notification center, which reaches no other process, and name a made-up app, so the tests do
/// not depend on what Launch Services lists.
@MainActor @Suite(.serialized)
final class SwitcherSystemWorkspaceTests {
    private let defaults = TestDefaults()
    private let workspace: SystemSwitcherWorkspace
    private let app = SwitcherTestRunningApplication()

    private var terminatedProcessIdentifiers: [pid_t] = []
    private var hiddenOrShownCount = 0

    init() {
        workspace = SystemSwitcherWorkspace(batchQuitStore: BatchQuitStore(defaults: defaults.buildUserDefaults()))
    }

    deinit {
        defaults.remove()
    }

    @Test
    func reportsQuitAppByProcessIdentifier() async {
        startObserving()

        post(NSWorkspace.didTerminateApplicationNotification)
        await drainMainQueue()

        #expect(terminatedProcessIdentifiers == [app.processIdentifier], "Quit app was not reported by its process identifier")
        #expect(hiddenOrShownCount == 0, "Quit was reported as hidden or shown")
        workspace.stopObserving()
    }

    @Test
    func forgetsQuitProcess() async {
        startObserving()

        post(NSWorkspace.didActivateApplicationNotification)
        await drainMainQueue()
        #expect(workspace.getRecentlyActiveProcessIdentifiers().first == app.processIdentifier, "Activated process was not tracked")

        post(NSWorkspace.didTerminateApplicationNotification)
        await drainMainQueue()
        #expect(!workspace.getRecentlyActiveProcessIdentifiers().contains(app.processIdentifier), "Quit process kept its place")
        workspace.stopObserving()
    }

    @Test
    func reportsHiddenAndShownApps() async {
        startObserving()

        post(NSWorkspace.didHideApplicationNotification)
        await drainMainQueue()
        #expect(hiddenOrShownCount == 1, "Hidden app was not reported")

        post(NSWorkspace.didUnhideApplicationNotification)
        await drainMainQueue()
        #expect(hiddenOrShownCount == 2, "Shown app was not reported")
        #expect(terminatedProcessIdentifiers.isEmpty, "Hiding or showing was reported as a quit")
        workspace.stopObserving()
    }

    @Test
    func stopsReporting() async {
        startObserving()
        workspace.stopObserving()

        post(NSWorkspace.didTerminateApplicationNotification)
        post(NSWorkspace.didHideApplicationNotification)
        post(NSWorkspace.didUnhideApplicationNotification)
        await drainMainQueue()

        #expect(terminatedProcessIdentifiers.isEmpty, "Stopped workspace reported a quit")
        #expect(hiddenOrShownCount == 0, "Stopped workspace reported hiding or showing")
    }

    private func startObserving() {
        workspace.startObserving(
            onAppTerminated: { processIdentifier in self.terminatedProcessIdentifiers.append(processIdentifier) },
            onAppHiddenOrShown: { self.hiddenOrShownCount += 1 }
        )
    }

    /// About the made-up app, as the workspace names the app in each of these notifications.
    private func post(_ name: Notification.Name) {
        NSWorkspace.shared.notificationCenter.post(name: name, object: NSWorkspace.shared, userInfo: [NSWorkspace.applicationUserInfoKey: app])
    }

    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}

/// An app with a process identifier beyond the ones macOS hands out, so it is never the frontmost app the tracker starts with.
final class SwitcherTestRunningApplication: NSRunningApplication, @unchecked Sendable {
    override var processIdentifier: pid_t { 999_999 }
}
