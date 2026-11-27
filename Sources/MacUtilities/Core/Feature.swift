import AppKit
import SwiftUI

/// One toggleable utility hosted by the app. The core starts the enabled features, hands every tapped event to them in order, the first to
/// swallow it winning, and stops them when switched off or on quit. A feature implements only the hooks it needs; the others do nothing.
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

    /// Called at launch while enabled, and when switched on.
    func start()
    /// Called when switched off, and on quit while enabled.
    func stop(because cause: FeatureStopCause)
    /// Finishes outstanding external effects, including cleanup owned by a disabled feature.
    @MainActor func prepareForTermination() async
    /// Returns true when the event is swallowed and must not reach the focused app.
    func handle(type: CGEventType, event: CGEvent) -> Bool
    /// The sections of the feature's settings pane, below the header with its name and switch.
    func buildSettingsSections() -> AnyView
    /// The settings window while it shows this feature's pane, nil once it does not.
    func settingsWindowChanged(_ window: AppKit.NSWindow?)
    /// The feature's tile in the menu bar popover while it is enabled; nil for a feature without one. The tile keeps itself current.
    func buildPopoverTile() -> AnyView?
}

extension Feature {
    func start() {}
    func stop(because cause: FeatureStopCause) {}
    @MainActor func prepareForTermination() async {}
    func handle(type: CGEventType, event: CGEvent) -> Bool { false }
    func settingsWindowChanged(_ window: AppKit.NSWindow?) {}
    func buildPopoverTile() -> AnyView? { nil }
}
