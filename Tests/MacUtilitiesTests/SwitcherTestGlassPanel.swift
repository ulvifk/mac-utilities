import AppKit
@testable import MacUtilities

/// The real switcher panel, whose ordering in and out only flips isVisible, so its own logic runs without a window on the screen.
final class SwitcherTestGlassPanel: GlassSwitcherPanel {
    private var isOrderedIn = false

    override var isVisible: Bool {
        return isOrderedIn
    }

    override func orderFrontRegardless() {
        isOrderedIn = true
    }

    override func orderOut(_ sender: Any?) {
        isOrderedIn = false
    }
}
