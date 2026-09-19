import AppKit

struct DockCell {
    let item: DockItem
    let frame: NSRect
}

enum DropMarker: Equatable {
    case insertionLine(CGFloat)
    case groupHighlight(NSRect)
}

struct DockDropPreview: Equatable {
    let target: DockDropTarget
    let marker: DropMarker
}

struct DockLayout {
    let cells: [DockCell]
    let size: NSSize

    static func build(items: [DockItem]) -> DockLayout {
        var x = stripEndPadding
        var cells: [DockCell] = []
        for item in items {
            let frame = NSRect(x: x, y: 0, width: item.width, height: stripHeight)
            cells.append(DockCell(item: item, frame: frame))
            x += item.width
        }
        return DockLayout(cells: cells, size: NSSize(width: x + stripEndPadding, height: stripHeight))
    }

    func getItemIndex(at point: NSPoint) -> Int? {
        return cells.firstIndex { $0.frame.contains(point) }
    }

    func getDropPreview(at point: NSPoint) -> DockDropPreview? {
        if cells.isEmpty { return nil }
        if !NSRect(origin: .zero, size: size).contains(point) { return nil }
        let index = getItemIndex(at: point) ?? (point.x < stripEndPadding ? 0 : cells.count - 1)
        let cell = cells[index]
        guard let group = cell.item.group else { return nil }
        guard let app = cell.item.app else {
            return DockDropPreview(target: DockDropTarget(group: group, beforeAppID: nil), marker: .groupHighlight(cell.frame))
        }
        let isBefore = point.x < cell.frame.midX
        let nextID = getNextAppID(after: index, in: group)
        let target = DockDropTarget(group: group, beforeAppID: isBefore ? app.id : nextID)
        return DockDropPreview(target: target, marker: .insertionLine(isBefore ? cell.frame.minX : cell.frame.maxX))
    }

    private func getNextAppID(after index: Int, in group: AppGroup) -> String? {
        for cell in cells.dropFirst(index + 1) {
            if cell.item.group != group { return nil }
            if let app = cell.item.app { return app.id }
        }
        return nil
    }
}
