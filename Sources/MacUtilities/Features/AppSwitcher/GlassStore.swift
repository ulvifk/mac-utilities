import Combine
import Foundation

/// How one list's glass looks, in UserDefaults under keys starting with the prefix: see-through or frosted, and how dark its tint is. The panel
/// reads it each time it opens.
final class GlassStore: ObservableObject {
    private let frostedKey: String
    private let darknessKey: String
    private let defaults = UserDefaults.standard

    init(keyPrefix: String) {
        frostedKey = keyPrefix + "Frosted"
        darknessKey = keyPrefix + "Darkness"
    }

    var isFrosted: Bool {
        return defaults.bool(forKey: frostedKey)
    }

    /// The black tint's opacity.
    var darkness: CGFloat {
        return defaults.object(forKey: darknessKey) as? CGFloat ?? defaultGlassDarkness
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
