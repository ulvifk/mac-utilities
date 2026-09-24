import AppKit

/// One toggleable utility hosted by the app. The core hands every tapped event to the enabled features in order; the first to swallow it wins.
protocol Feature {
    /// Stable key the enabled state is stored under; never rename it.
    var identifier: String { get }
    var displayName: String { get }

    func start()
    func stop()
    /// Returns true when the event is swallowed and must not reach the focused app.
    func handle(type: CGEventType, event: CGEvent) -> Bool
    /// The feature's own entries in the menu bar menu.
    func buildMenuItems() -> [NSMenuItem]
}
