import Combine
import Foundation

/// Whether the window switcher frames each window in a card, in UserDefaults; on until switched off. The panel reads it each time it opens.
final class WindowCardStore: ObservableObject {
    private let showsCardsKey = "windowCards"
    private let defaults = UserDefaults.standard

    var showsCards: Bool {
        return defaults.object(forKey: showsCardsKey) as? Bool ?? true
    }

    func setShowsCards(_ showsCards: Bool) {
        objectWillChange.send()
        defaults.set(showsCards, forKey: showsCardsKey)
    }
}
