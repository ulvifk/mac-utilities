import Combine

/// Holds the scanned application folders for the life of the settings tab, so the tab does not rescan on every redraw.
final class InstalledApps: ObservableObject {
    let apps = getInstalledApps()
}
