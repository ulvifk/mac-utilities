import AppKit
import SwiftUI

/// The settings window, kept around across closes; its title follows the selected pane. The app is an accessory, so opening it activates the
/// app; the system may turn that down and leave the window behind the frontmost app's, so it is also ordered front regardless.
final class SettingsWindow: NSWindow, NSWindowDelegate, NSToolbarDelegate {
    private var splitViewController: SettingsSplitViewController!

    init(controller: AppController) {
        super.init(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)

        splitViewController = SettingsSplitViewController(panes: buildPanes(controller: controller))
        isReleasedWhenClosed = false
        delegate = self
        toolbar = buildToolbar()
        toolbarStyle = .unifiedCompact
        contentViewController = splitViewController
        setContentSize(settingsWindowSize)
        contentMinSize = NSSize(width: settingsWindowSize.width, height: settingsWindowMinimumHeight)
        center()

        // Every pane is still shown here, so SwiftUI builds them all now rather than on the first switch to each.
        layoutIfNeeded()
        showPane(generalPaneIdentifier)
    }

    func open() {
        NSApp.activate()
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
        splitViewController.setSettingsVisible(true)
    }

    func showPane(_ paneIdentifier: String) {
        splitViewController.showPane(paneIdentifier)
    }

    func windowWillClose(_ notification: Notification) {
        splitViewController.setSettingsVisible(false)
    }

    func windowDidMiniaturize(_ notification: Notification) {
        splitViewController.setSettingsVisible(false)
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        splitViewController.setSettingsVisible(true)
    }

    func windowDidMove(_ notification: Notification) {
        splitViewController.updateVisiblePane()
    }

    func windowDidResize(_ notification: Notification) {
        splitViewController.updateVisiblePane()
    }

    /// The separator tracking the sidebar's edge puts the title over the pane rather than over the sidebar.
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.sidebarTrackingSeparator]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.sidebarTrackingSeparator]
    }

    private func buildToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "settings")

        toolbar.delegate = self

        return toolbar
    }

    /// General, then one pane per feature.
    private func buildPanes(controller: AppController) -> [SettingsPane] {
        let generalView = GeneralSettingsView(controller: controller) { [unowned self] paneIdentifier in self.showPane(paneIdentifier) }
        let general = SettingsPane(
            identifier: generalPaneIdentifier,
            title: "General",
            symbolName: generalIconSymbolName,
            gradient: generalIconGradient,
            warning: getGeneralWarning(controller: controller),
            view: AnyView(generalView),
            onWindowChanged: { _ in }
        )

        return [general] + controller.features.map { feature in
            SettingsPane(
                identifier: feature.identifier,
                title: feature.displayName,
                symbolName: feature.iconSymbolName,
                gradient: feature.iconGradient,
                warning: nil,
                view: AnyView(FeatureSettingsPane(controller: controller, feature: feature)),
                onWindowChanged: feature.settingsWindowChanged
            )
        }
    }

    /// The event tap is created only at launch, so this holds for the window's life.
    private func getGeneralWarning(controller: AppController) -> String? {
        if controller.isEventTapRunning { return nil }
        return "Shortcuts are off until Accessibility is allowed and MacUtilities reopened"
    }
}
