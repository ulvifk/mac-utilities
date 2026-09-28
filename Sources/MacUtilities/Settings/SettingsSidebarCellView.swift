import AppKit
import SwiftUI

/// A pane's row in the sidebar: its icon tile, its name and, when the pane has a warning, a badge at the trailing edge. The name is the cell's
/// text field, so it turns white on the selection like any sidebar row's.
final class SettingsSidebarCellView: NSTableCellView {
    let paneIdentifier: String

    init(pane: SettingsPane) {
        paneIdentifier = pane.identifier
        super.init(frame: .zero)

        let icon = NSHostingView(rootView: SettingsIconTile(symbolName: pane.symbolName, gradient: pane.gradient, size: smallIconTileSize))
        let title = NSTextField(labelWithString: pane.title)
        let warningBadge = NSImageView(image: NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: pane.warning)!)

        title.lineBreakMode = .byTruncatingTail
        warningBadge.symbolConfiguration = .preferringMulticolor()
        warningBadge.toolTip = pane.warning
        warningBadge.isHidden = pane.warning == nil
        textField = title

        for view in [icon, title, warningBadge] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: smallIconTileSize),
            icon.heightAnchor.constraint(equalToConstant: smallIconTileSize),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: sidebarIconTitleSpacing),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            title.trailingAnchor.constraint(lessThanOrEqualTo: warningBadge.leadingAnchor, constant: -sidebarIconTitleSpacing),
            warningBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -sidebarBadgeTrailingInset),
            warningBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("never decoded from a nib")
    }
}
