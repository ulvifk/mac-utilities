import Combine

/// Holds the scanned application folders for the life of the settings pane, so the pane does not rescan on every redraw.
final class InstalledApps: ObservableObject {
    let apps = getInstalledApps()
}
