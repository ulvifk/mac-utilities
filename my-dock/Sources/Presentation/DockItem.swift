import AppKit

struct AppTile: Equatable {
    let app: SavedApp
    let group: AppGroup
    let isRunning: Bool
    let badge: String?
}

struct ToggleSlot: Equatable {
    let isCollapsed: Bool
    let hiddenCount: Int
    let hasBadge: Bool
}

enum DockItem: Equatable {
    case application(AppTile)
    case toggle(ToggleSlot)
    case emptyGroup(AppGroup)
    case separator
    case trash

    var app: SavedApp? {
        guard case .application(let tile) = self else { return nil }
        return tile.app
    }

    var group: AppGroup? {
        switch self {
        case .application(let tile): return tile.group
        case .toggle: return .hidden
        case .emptyGroup(let group): return group
        case .separator, .trash: return nil
        }
    }

    var name: String {
        switch self {
        case .application(let tile): return tile.app.name
        case .toggle(let slot):
            let verb = slot.isCollapsed ? "Show" : "Collapse"
            return "\(verb) hidden apps (\(slot.hiddenCount)); drop an app here to hide its icon"
        case .emptyGroup(let group): return "Drop apps here to keep them \(group.rawValue)"
        case .separator: return ""
        case .trash: return "Trash"
        }
    }

    var accessibilityID: String {
        switch self {
        case .application(let tile): return tile.app.id
        case .toggle: return "toggle"
        case .emptyGroup(let group): return "empty-\(group.rawValue)"
        case .separator: return "separator"
        case .trash: return "trash"
        }
    }

    var tooltip: String {
        guard case .toggle(let slot) = self else { return name }
        let verb = slot.isCollapsed ? "Show" : "Collapse"
        return "\(verb) hidden apps · drop here to hide"
    }

    var primaryAction: DockAction? {
        switch self {
        case .application(let tile): return .openApp(tile.app)
        case .toggle: return .edit(.toggleHiddenGroup)
        case .trash: return .openTrash
        case .emptyGroup, .separator: return nil
        }
    }

    var width: CGFloat {
        switch self {
        case .application, .emptyGroup, .trash: return 48
        case .separator: return 12
        case .toggle(let slot):
            if !slot.isCollapsed { return toggleSlotWidth }
            return toggleSlotWidth + ceil(getToggleCountSize(slot).width) + toggleCountGap
        }
    }
}

func getToggleCountSize(_ slot: ToggleSlot) -> NSSize {
    return ("\(slot.hiddenCount)" as NSString).size(withAttributes: toggleCountAttributes)
}

enum DockItems {
    static func build(state: DockState, runningIDs: Set<String>, badges: [String: String]) -> [DockItem] {
        let visible = state.visibleApps.filter { $0.isDisplayed(runningIDs: runningIDs) }
        let hidden = state.hiddenApps.filter { $0.isDisplayed(runningIDs: runningIDs) }
        var items = visible.map { buildAppItem($0, group: .visible, runningIDs: runningIDs, badges: badges) }
        if items.isEmpty { items.append(.emptyGroup(.visible)) }
        let hiddenHasBadge = hidden.contains { badges[$0.url.path] != nil }
        items.append(.toggle(ToggleSlot(isCollapsed: state.isCollapsed, hiddenCount: hidden.count, hasBadge: hiddenHasBadge)))
        if !state.isCollapsed {
            items.append(contentsOf: hidden.map { buildAppItem($0, group: .hidden, runningIDs: runningIDs, badges: badges) })
        }
        items.append(.separator)
        items.append(.trash)
        return items
    }

    private static func buildAppItem(_ app: SavedApp, group: AppGroup, runningIDs: Set<String>, badges: [String: String]) -> DockItem {
        return .application(AppTile(app: app, group: group, isRunning: runningIDs.contains(app.id), badge: badges[app.url.path]))
    }
}
