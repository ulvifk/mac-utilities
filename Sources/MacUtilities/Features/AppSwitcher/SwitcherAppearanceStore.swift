import Combine
import Foundation

final class SwitcherAppearanceStore: ObservableObject {
    private let dimHiddenAppsKey = "dimHiddenApps"
    private let defaults = UserDefaults.standard

    var dimHiddenApps: Bool {
        return defaults.object(forKey: dimHiddenAppsKey) as? Bool ?? true
    }

    func setDimHiddenApps(_ dimHiddenApps: Bool) {
        objectWillChange.send()
        defaults.set(dimHiddenApps, forKey: dimHiddenAppsKey)
    }
}
