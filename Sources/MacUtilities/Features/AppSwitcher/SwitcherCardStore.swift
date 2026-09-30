import Combine
import Foundation

final class SwitcherCardStore: ObservableObject {
    private let key: String
    private let defaults = UserDefaults.standard

    init(key: String) {
        self.key = key
    }

    var showsCards: Bool {
        return defaults.object(forKey: key) as? Bool ?? true
    }

    func setShowsCards(_ showsCards: Bool) {
        objectWillChange.send()
        defaults.set(showsCards, forKey: key)
    }
}
