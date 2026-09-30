import AppKit
import SwiftUI

/// The sidebar and, beside it, the selected pane. Every pane is built once and kept, the others hidden, so switching only swaps which one is
/// visible; a hidden pane takes no clicks or keys.
final class SettingsSplitViewController: NSSplitViewController {
    private let panes: [SettingsPane]
    private let sidebar: SettingsSidebarViewController
    /// [pane identifier] -> the pane's view
    private let paneViews: [String: NSView]

    private var selectedPaneIdentifier = generalPaneIdentifier
    private var areSettingsVisible = false

    init(panes: [SettingsPane]) {
        self.panes = panes
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

    func setSettingsVisible(_ isVisible: Bool) {
        if areSettingsVisible == isVisible { return }

        areSettingsVisible = isVisible
        getPane(selectedPaneIdentifier).onWindowChanged(isVisible ? view.window! : nil)
    }

    func updateVisiblePane() {
        if !areSettingsVisible { return }

        getPane(selectedPaneIdentifier).onWindowChanged(view.window!)
    }

    /// The pane's title becomes the window's.
    private func showSelectedPane(_ paneIdentifier: String) {
        if selectedPaneIdentifier != paneIdentifier {
            getPane(selectedPaneIdentifier).onWindowChanged(nil)
            selectedPaneIdentifier = paneIdentifier
            getPane(paneIdentifier).onWindowChanged(areSettingsVisible ? view.window! : nil)
        }

        for (identifier, paneView) in paneViews {
            paneView.isHidden = identifier != paneIdentifier
        }

        view.window!.title = getPane(paneIdentifier).title
    }

    private func getPane(_ identifier: String) -> SettingsPane {
        return panes.first { $0.identifier == identifier }!
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
