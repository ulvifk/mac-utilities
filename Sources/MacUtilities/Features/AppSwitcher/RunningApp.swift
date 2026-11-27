import AppKit

/// A running app with a bundle identifier, as the workspace has it.
final class RunningApp: SwitcherApp {
    let runningApplication: NSRunningApplication

    init(runningApplication: NSRunningApplication) {
        self.runningApplication = runningApplication
    }

    var bundleIdentifier: String {
        return runningApplication.bundleIdentifier!
    }

    var processIdentifier: pid_t {
        return runningApplication.processIdentifier
    }

    var name: String {
        return getAppName(runningApplication)
    }

    var icon: NSImage? {
        return runningApplication.icon
    }

    var isHidden: Bool {
        return runningApplication.isHidden
    }

    func activate() {
        runningApplication.activate(options: [.activateAllWindows])
    }

    func hide() {
        runningApplication.hide()
    }

    func terminate() {
        runningApplication.terminate()
    }
}
