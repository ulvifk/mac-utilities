import AppKit

/// A running app as the switcher lists it and acts on it.
protocol SwitcherApp: AnyObject {
    var bundleIdentifier: String { get }
    var processIdentifier: pid_t { get }
    /// The localized name, or the bundle identifier for an app without one.
    var name: String { get }
    var icon: NSImage? { get }
    var isHidden: Bool { get }

    /// Brings the app to the front with all its windows, unhiding it.
    func activate()
    func hide()
    /// A normal quit, so an app with unsaved changes asks first.
    func terminate()
}
