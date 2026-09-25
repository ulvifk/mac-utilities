import Foundation

/// The panel width chosen by dragging its edge, in UserDefaults; nil until the panel has been resized once.
final class PanelWidthStore {
    private let widthKey = "panelWidth"
    private let defaults = UserDefaults.standard

    var width: CGFloat? {
        return defaults.object(forKey: widthKey) as? CGFloat
    }

    func setWidth(_ width: CGFloat) {
        defaults.set(width, forKey: widthKey)
    }
}
