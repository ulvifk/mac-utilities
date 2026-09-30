import AppKit
import SwiftUI

// Native window construction stays real; presentation and application activation are isolated.
class NSWindow: AppKit.NSWindow {
    override func makeKeyAndOrderFront(_ sender: Any?) {}
    override func orderFrontRegardless() {}
}

final class SettingsTestApplication {
    func activate() {}
}

let NSApp = SettingsTestApplication()

final class AppController {
    let features: [Feature]
    let isEventTapRunning = true

    init(features: [Feature]) {
        self.features = features
    }
}

final class SettingsTestFeature: Feature {
    let identifier = "test-feature"
    let displayName = "Test Feature"
    let summary = "Test settings lifecycle"
    let iconSymbolName = "square"
    let iconGradient = Gradient(colors: [.blue])

    var visibilityChanges: [Bool] = []
    weak var currentWindow: AppKit.NSWindow?

    func start() {}
    func stop() {}
    func handle(type: CGEventType, event: CGEvent) -> Bool { false }
    func buildSettingsSections() -> AnyView { AnyView(EmptyView()) }
    func buildPopoverTile() -> AnyView? { nil }
    func settingsWindowChanged(_ window: AppKit.NSWindow?) {
        currentWindow = window
        visibilityChanges.append(window != nil)
    }
}

struct GeneralSettingsView: View {
    let controller: AppController
    let onShowPane: (String) -> Void

    var body: some View { EmptyView() }
}

struct FeatureSettingsPane: View {
    let controller: AppController
    let feature: Feature

    var body: some View { EmptyView() }
}

final class SettingsSidebarViewController: NSViewController {
    static var instance: SettingsSidebarViewController!

    var onSelect: (String) -> Void = { _ in }

    init(panes: [SettingsPane]) {
        super.init(nibName: nil, bundle: nil)
        Self.instance = self
        view = NSView()
    }

    required init?(coder: NSCoder) {
        fatalError("never decoded from a nib")
    }

    func select(_ paneIdentifier: String) {}
}
