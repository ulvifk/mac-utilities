import CoreGraphics

let visible = CGRect(x: 4, y: 0, width: 1436, height: 875)
let area = MaximizedWindowArea(visibleFrame: visible, reservedTop: 70, primaryScreenTop: 900)
let maximized = area.getAdjustedFrame(visible)!
assert(maximized == CGRect(x: 4, y: 70, width: 1436, height: 805))
assert(maximized.maxY == visible.maxY)
assert(area.getAdjustedFrame(maximized) == nil)

for margin: CGFloat in [8, 16] {
    let inset = visible.insetBy(dx: margin, dy: margin)
    let tiled = area.getAdjustedFrame(inset)!
    assert(tiled.origin.x == inset.origin.x)
    assert(tiled.width == inset.width)
    assert(tiled.maxY == inset.maxY)
    assert(tiled.minY == 70)
}

assert(area.getAdjustedFrame(CGRect(x: 160, y: 0, width: 1000, height: 800)) == nil)
assert(area.getAdjustedFrame(CGRect(x: 4, y: 0, width: 700, height: 875)) == nil)
assert(area.getAdjustedFrame(CGRect(x: 4, y: 0, width: 1436, height: 400)) == nil)
assert(area.getAdjustedFrame(CGRect(x: 4, y: 180, width: 1436, height: 695)) == nil)
assert(area.getAdjustedFrame(CGRect(x: 0, y: 0, width: 1440, height: 900)) == nil)
assert(area.getAdjustedFrame(CGRect(x: 1440, y: 0, width: 1440, height: 875)) == nil)

let left = MaximizedWindowArea(visibleFrame: CGRect(x: -1920, y: -200, width: 1920, height: 1055), reservedTop: -130, primaryScreenTop: 900)
let leftMaximized = left.getAdjustedFrame(left.visibleFrame)!
assert(leftMaximized == CGRect(x: -1920, y: -130, width: 1920, height: 985))
let accessibility = left.convertScreenCoordinates(leftMaximized)
assert(accessibility == CGRect(x: -1920, y: 45, width: 1920, height: 985))
assert(left.convertScreenCoordinates(accessibility) == leftMaximized)
assert(left.convertScreenCoordinates(left.visibleFrame).minY == accessibility.minY)

let above = MaximizedWindowArea(visibleFrame: CGRect(x: 0, y: 900, width: 1440, height: 875), reservedTop: 970, primaryScreenTop: 900)
let aboveMaximized = above.getAdjustedFrame(above.visibleFrame)!
assert(above.convertScreenCoordinates(aboveMaximized).minY == -875)
assert(above.getAdjustedFrame(visible) == nil)

let alreadyReserved = MaximizedWindowArea(visibleFrame: CGRect(x: 0, y: 100, width: 1440, height: 775), reservedTop: 70, primaryScreenTop: 900)
assert(alreadyReserved.getAdjustedFrame(alreadyReserved.visibleFrame) == nil)
print("Passed: maximize bounds, tiling margins, fixed window top, repeated notifications, floating/half-tiled/full-screen exclusion, other displays, coordinate conversion.")
