import CoreGraphics

/// One window of an app as the switcher lists it.
protocol SwitcherWindow {
    /// The id the window server knows it by, which its thumbnail is captured and kept under; 0 when it is not known.
    var windowID: CGWindowID { get }
    /// The window's own title, or its app's name for an untitled window.
    var title: String { get }

    /// Unminimizes the window, raises it above the app's other windows and activates the app without bringing those along.
    func bringToFront()
}
