import Combine
import Foundation

/// How the panel's glass looks, in UserDefaults: see-through or frosted, and how dark its tint is. The panel reads it each time it opens.
final class GlassStore: ObservableObject {
    private let frostedKey = "glassFrosted"
    private let darknessKey = "glassDarkness"
    private let defaults = UserDefaults.standard

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
