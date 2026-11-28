import Combine
import Foundation

/// Whether the switcher shows the apps' Dock badges; while it is off neither the switcher nor its preview reads the Dock.
final class DockBadgeStore: ObservableObject {
    private let showsBadgesKey = "dockBadges"
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var showsBadges: Bool {
        return defaults.object(forKey: showsBadgesKey) as? Bool ?? true
    }

    func setShowsBadges(_ showsBadges: Bool) {
        objectWillChange.send()
        defaults.set(showsBadges, forKey: showsBadgesKey)
    }
}
