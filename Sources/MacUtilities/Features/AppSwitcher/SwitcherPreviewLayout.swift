import AppKit

func getPreviewFrame(contentSize: NSSize, settingsFrame: NSRect, screenFrame: NSRect) -> NSRect {
    let gap: CGFloat = 12
    let centeredX = min(max(settingsFrame.midX - contentSize.width / 2, screenFrame.minX), screenFrame.maxX - contentSize.width)
    let centeredY = min(max(settingsFrame.midY - contentSize.height / 2, screenFrame.minY), screenFrame.maxY - contentSize.height)

    let rightX = max(settingsFrame.maxX + gap, screenFrame.minX)
    if rightX + contentSize.width <= screenFrame.maxX {
        return NSRect(x: rightX, y: centeredY, width: contentSize.width, height: contentSize.height)
    }

    let leftX = min(settingsFrame.minX - gap - contentSize.width, screenFrame.maxX - contentSize.width)
    if leftX >= screenFrame.minX {
        return NSRect(x: leftX, y: centeredY, width: contentSize.width, height: contentSize.height)
    }

    let belowY = min(settingsFrame.minY - gap - contentSize.height, screenFrame.maxY - contentSize.height)
    if belowY >= screenFrame.minY {
        return NSRect(x: centeredX, y: belowY, width: contentSize.width, height: contentSize.height)
    }

    let aboveY = max(settingsFrame.maxY + gap, screenFrame.minY)
    if aboveY + contentSize.height <= screenFrame.maxY {
        return NSRect(x: centeredX, y: aboveY, width: contentSize.width, height: contentSize.height)
    }

    return NSRect(origin: screenFrame.origin, size: contentSize)
}
