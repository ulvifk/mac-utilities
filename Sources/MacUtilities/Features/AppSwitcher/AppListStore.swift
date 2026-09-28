import Combine

/// A saved set of apps, by bundle identifier, that the settings pane edits with an `AppListPicker`.
protocol AppListStore: ObservableObject {
    func isListed(_ bundleIdentifier: String) -> Bool
    func setListed(_ bundleIdentifier: String, _ listed: Bool)
}
