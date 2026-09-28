import Combine
import Foundation

/// How one glass looks, a list's panel or the window cards, in UserDefaults under keys starting with the prefix: see-through or frosted, and
/// how dark its tint is. The panel reads it each time it opens.
final class GlassStore: ObservableObject {
    private let frostedKey: String
    private let darknessKey: String
    /// Until the darkness slider is moved.
    private let defaultDarkness: CGFloat
    private let defaults = UserDefaults.standard

    init(keyPrefix: String, defaultDarkness: CGFloat) {
        frostedKey = keyPrefix + "Frosted"
        darknessKey = keyPrefix + "Darkness"
        self.defaultDarkness = defaultDarkness
    }

    var isFrosted: Bool {
        return defaults.bool(forKey: frostedKey)
    }

    /// The black tint's opacity.
    var darkness: CGFloat {
        return defaults.object(forKey: darknessKey) as? CGFloat ?? defaultDarkness
    }

    func setFrosted(_ frosted: Bool) {
        objectWillChange.send()
        defaults.set(frosted, forKey: frostedKey)
    }

    func setDarkness(_ darkness: CGFloat) {
        objectWillChange.send()
        defaults.set(darkness, forKey: darknessKey)
    }
}
