import AppKit

final class DockAccessibilityElement: NSAccessibilityElement {
    private unowned let view: DockStripView
    private let item: DockItem

    init(view: DockStripView, item: DockItem, frame: NSRect) {
        self.view = view
        self.item = item
        super.init()

        setAccessibilityRole(.button)
        setAccessibilityEnabled(true)
        setAccessibilityLabel(item.name)
        setAccessibilityParent(view)
        setAccessibilityFrameInParentSpace(frame)
        setAccessibilityIdentifier(item.accessibilityID)
        if let group = item.group { setAccessibilityHelp("\(group.rawValue.capitalized) group") }
    }

    override func accessibilityPerformPress() -> Bool {
        view.activateItem(item)
        return true
    }

    override func accessibilityPerformShowMenu() -> Bool {
        view.showMenu(for: item)
        return true
    }
}
