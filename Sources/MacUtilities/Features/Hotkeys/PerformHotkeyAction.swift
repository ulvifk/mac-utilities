import AppKit

func performHotkeyAction(_ action: HotkeyAction, toggleKeepAwake: () -> Void) {
    switch action.type {
    case .activateApp: activateOrLaunchApp(bundleIdentifier: action.target)
    case .toggleApp: toggleApp(bundleIdentifier: action.target)
    case .runCommand: runShellCommand(action.target)
    case .toggleKeepAwake: toggleKeepAwake()
    }
}

/// Launches the app or brings it to the front; a running app with no windows gets the reopen that makes it open one.
func activateOrLaunchApp(bundleIdentifier: String) {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
        print("hotkeys: no app installed with bundle identifier \(bundleIdentifier)")
        return
    }

    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
}

/// Hides the app when it is frontmost, otherwise brings it to the front like activateOrLaunchApp.
func toggleApp(bundleIdentifier: String) {
    if let app = getRunningApp(bundleIdentifier: bundleIdentifier), app.isActive {
        app.hide()
        return
    }

    activateOrLaunchApp(bundleIdentifier: bundleIdentifier)
}

/// Through /bin/sh -c with the app's environment, output discarded, not waited for; the command outlives the app.
func runShellCommand(_ command: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", command]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    try! process.run()
}

private func getRunningApp(bundleIdentifier: String) -> NSRunningApplication? {
    return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
}
