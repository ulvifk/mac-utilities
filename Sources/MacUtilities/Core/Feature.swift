import AppKit
import SwiftUI

/// One toggleable utility hosted by the app. The core hands every tapped event to the enabled features in order; the first to swallow it wins.
protocol Feature {
    /// Stable key the enabled state is stored under; never rename it.
    var identifier: String { get }
    var displayName: String { get }
    /// One plain sentence saying what the feature does, under its name at the top of its settings pane.
    var summary: String { get }
    /// The white symbol on the feature's icon tile in the settings window.
    var iconSymbolName: String { get }
    /// The icon tile's fill, top to bottom.
    var iconGradient: Gradient { get }

    func start()
    func stop()
    /// Returns true when the event is swallowed and must not reach the focused app.
    func handle(type: CGEventType, event: CGEvent) -> Bool
    /// The sections of the feature's settings pane, below the header with its name and switch.
    func buildSettingsSections() -> AnyView
    /// The feature's tile in the menu bar popover while it is enabled; nil for most. The tile keeps itself current.
    func buildPopoverTile() -> AnyView?
}
