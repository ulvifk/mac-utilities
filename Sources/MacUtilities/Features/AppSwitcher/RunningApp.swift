import AppKit
import os

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
        if runningApplication.activate(options: [.activateAllWindows]) { return }
        Logger.appSwitcher.error("\(self.name, privacy: .public) (\(self.bundleIdentifier, privacy: .public)) refused to activate")
    }

    func hide() {
        if runningApplication.hide() { return }
        Logger.appSwitcher.error("\(self.name, privacy: .public) (\(self.bundleIdentifier, privacy: .public)) refused to hide")
    }

    func terminate() {
        if runningApplication.terminate() { return }
        Logger.appSwitcher.error("\(self.name, privacy: .public) (\(self.bundleIdentifier, privacy: .public)) refused to quit")
    }
}
