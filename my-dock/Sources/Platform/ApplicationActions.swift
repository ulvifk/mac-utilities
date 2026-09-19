import AppKit

enum ApplicationActions {
    static func open(_ app: SavedApp) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: app.url, configuration: configuration) { _, error in
            guard let error else { return }
            DispatchQueue.main.async { NSAlert(error: error).runModal() }
        }
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func quit(_ app: SavedApp) {
        for running in NSRunningApplication.runningApplications(withBundleIdentifier: app.id) {
            running.terminate()
        }
    }

    static func openTrash() {
        NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash"))
    }
}
