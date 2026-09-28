import AppKit
import SwiftUI

/// A pane's row in the sidebar: its icon tile and its name. The name is the cell's text field, so it turns white on the selection like any
/// sidebar row's.
final class SettingsSidebarCellView: NSTableCellView {
    let paneIdentifier: String

    init(pane: SettingsPane) {
        paneIdentifier = pane.identifier
        super.init(frame: .zero)

        let icon = NSHostingView(rootView: SettingsIconTile(symbolName: pane.symbolName, gradient: pane.gradient, size: smallIconTileSize))
        let title = NSTextField(labelWithString: pane.title)

        title.lineBreakMode = .byTruncatingTail
        textField = title

        for view in [icon, title] as [NSView] {
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
            title.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("never decoded from a nib")
    }
}
