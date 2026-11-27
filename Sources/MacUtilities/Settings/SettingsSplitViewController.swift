import AppKit
import SwiftUI

/// The sidebar and, beside it, the selected pane. Every pane is built once and kept, the others hidden, so switching only swaps which one is
/// visible; a hidden pane takes no clicks or keys.
final class SettingsSplitViewController: NSSplitViewController {
    private let sidebar: SettingsSidebarViewController
    private let paneSelection: SettingsPaneSelection
    /// [pane identifier] -> the pane's view
    private let paneViews: [String: NSView]

    init(panes: [SettingsPane], paneSelection: SettingsPaneSelection) {
        self.paneSelection = paneSelection
        sidebar = SettingsSidebarViewController(panes: panes)
        paneViews = Dictionary(uniqueKeysWithValues: panes.map { ($0.identifier, buildPaneView($0)) })
        super.init(nibName: nil, bundle: nil)

        sidebar.onSelect = { [unowned self] paneIdentifier in self.showSelectedPane(paneIdentifier) }
        addSplitViewItem(buildSidebarItem())
        addSplitViewItem(NSSplitViewItem(viewController: buildPaneContainer()))
    }

    required init?(coder: NSCoder) {
        fatalError("never decoded from a nib")
    }

    /// Selecting the row in code does not always report it, before the window is shown for one, so the pane is shown here too.
    func showPane(_ paneIdentifier: String) {
        sidebar.select(paneIdentifier)
        showSelectedPane(paneIdentifier)
    }

    private func showSelectedPane(_ paneIdentifier: String) {
        paneSelection.selectPane(paneIdentifier)

        for (identifier, paneView) in paneViews {
            paneView.isHidden = identifier != paneIdentifier
        }
    }

    private func buildSidebarItem() -> NSSplitViewItem {
        let item = NSSplitViewItem(sidebarWithViewController: sidebar)

        item.canCollapse = false
        item.minimumThickness = settingsSidebarWidth
        item.maximumThickness = settingsSidebarWidth

        return item
    }

    /// Every pane fills it, stacked; all are shown until the first switch hides the others.
    private func buildPaneContainer() -> NSViewController {
        let container = NSViewController()

        container.view = NSView()
        for paneView in paneViews.values {
            paneView.autoresizingMask = [.width, .height]
            container.view.addSubview(paneView)
        }

        return container
    }
}

/// Sized by the window, never the other way round.
private func buildPaneView(_ pane: SettingsPane) -> NSView {
    let paneView = NSHostingView(rootView: pane.view)

    paneView.sizingOptions = []

    return paneView
}
