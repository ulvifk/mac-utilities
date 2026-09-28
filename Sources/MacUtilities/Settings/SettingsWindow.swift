import AppKit
import SwiftUI

/// The settings window, kept around across closes; its title follows the selected pane. The app is an accessory, so opening it activates the
/// app; the system may turn that down and leave the window behind the frontmost app's, so it is also ordered front regardless.
final class SettingsWindow: NSWindow, NSToolbarDelegate {
    private var splitViewController: SettingsSplitViewController!

    init(controller: AppController) {
        super.init(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)

        splitViewController = SettingsSplitViewController(panes: buildPanes(controller: controller))
        isReleasedWhenClosed = false
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
    }

    func showPane(_ paneIdentifier: String) {
        splitViewController.showPane(paneIdentifier)
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

    /// General, then one pane per feature, holding its sections in a form.
    private func buildPanes(controller: AppController) -> [SettingsPane] {
        let general = SettingsPane(identifier: generalPaneIdentifier, title: "General", symbolName: generalIconSymbolName, gradient: generalIconGradient, view: AnyView(GeneralSettingsView(controller: controller)))

        return [general] + controller.features.map { feature in
            SettingsPane(
                identifier: feature.identifier,
                title: feature.displayName,
                symbolName: feature.iconSymbolName,
                gradient: feature.iconGradient,
                view: AnyView(Form { feature.buildSettingsSections() }.formStyle(.grouped))
            )
        }
    }
}
