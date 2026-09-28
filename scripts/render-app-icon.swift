import AppKit
import CoreImage
import SwiftUI

// Renders Resources/AppIcon.icns: three frosted glass tiles cascading on a midnight body, the front one a ⌘ key.
// Run with `swift scripts/render-app-icon.swift`; the PNGs are kept in .build/AppIcon.iconset.

let repositoryURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconsetURL = repositoryURL.appendingPathComponent(".build/AppIcon.iconset")
let icnsURL = repositoryURL.appendingPathComponent("Resources/AppIcon.icns")
/// No 1x 16 and 32: iconutil stores those as legacy ARGB, which macOS 26 draws shrunk in a gray frame; without them it scales the 64 down.
let iconsetEntries: [(name: String, pixelSize: Int)] = [
    ("icon_16x16@2x", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

/// Every length below is in points of the 1024pt canvas, which is scaled to each pixel size.
let canvasSize: CGFloat = 1024
let bodyRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyCornerRadius: CGFloat = 185
let bodyTopColor = buildColor(0x2B3452)
let bodyBottomColor = buildColor(0x0D101D)
let bodyShadowColor = buildColor(0x000000, alpha: 0.35)
let bodyShadowOffset: CGFloat = 10
let bodyShadowBlur: CGFloat = 24
let bodyRimWidth: CGFloat = 4
let bodyRimTopAlpha: CGFloat = 0.45
let bodyRimBottomAlpha: CGFloat = 0.15
/// The light the glass tiles seem to cast on the body behind them.
let glowColor = buildColor(0x4A6BFF, alpha: 0.3)
let glowCenter = CGPoint(x: 560, y: 560)
let glowRadius: CGFloat = 440

/// Back to front: the amber and blue tiles behind, the white ⌘ key in front. The alpha lets the frosted backdrop show through.
let tileGradients: [(top: CGColor, bottom: CGColor)] = [
    (buildColor(0xFFB547, alpha: 0.9), buildColor(0xFF6F2E, alpha: 0.85)),
    (buildColor(0x62B8FF, alpha: 0.78), buildColor(0x2F5BEA, alpha: 0.75)),
    (buildColor(0xFFFFFF, alpha: 0.88), buildColor(0xE2E7F4, alpha: 0.8)),
]
let tileCornerRadiusRatio: CGFloat = 0.23
/// How blurred the tiles and body behind a tile show through it.
let tileFrostBlur: CGFloat = 40
/// A white sheen over the top of each tile, fading out this far down it.
let tileSheenAlpha: CGFloat = 0.16
let tileSheenReach: CGFloat = 0.55
let tileShadowColor = buildColor(0x00000D, alpha: 0.5)
let tileShadowOffsetRatio: CGFloat = 0.05
let tileShadowBlurRatio: CGFloat = 0.16
let tileRimWidthRatio: CGFloat = 0.009
let tileRimTopAlpha: CGFloat = 0.9
let tileRimBottomAlpha: CGFloat = 0.35
/// Each tile sits one step up and right of the one in front of it and is smaller by the shrink, so the stack recedes.
let largeTileLayout = (frontSize: CGFloat(440), step: CGFloat(84), shrink: CGFloat(36))
/// At 32 pixels the steps would blur together, so the tiles fan out further and the ⌘ is left out.
let smallTileLayout = (frontSize: CGFloat(480), step: CGFloat(130), shrink: CGFloat(0))
let smallIconMaxPixelSize = 32

let commandSymbolHeightRatio: CGFloat = 0.44
let commandSymbolWeight = NSFont.Weight.semibold
let commandTopColor = buildColor(0x3A4358)
let commandBottomColor = buildColor(0x1A1F2C)

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let imageContext = CIContext()

func buildColor(_ hex: Int, alpha: CGFloat = 1) -> CGColor {
    let red = CGFloat((hex >> 16) & 0xFF) / 255
    let green = CGFloat((hex >> 8) & 0xFF) / 255
    let blue = CGFloat(hex & 0xFF) / 255
    return CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

func buildRoundedRectPath(_ rect: CGRect, cornerRadius: CGFloat) -> CGPath {
    return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect).cgPath
}

/// Tiles back to front, the stack centred on the canvas.
func buildTileRects(frontSize: CGFloat, step: CGFloat, shrink: CGFloat) -> [CGRect] {
    let backDepth = CGFloat(tileGradients.count - 1)
    let frontOrigin = canvasSize / 2 - (frontSize + backDepth * step) / 2
    let front = CGRect(x: frontOrigin, y: frontOrigin, width: frontSize, height: frontSize)

    var rects: [CGRect] = []
    for depth in stride(from: backDepth, through: 0, by: -1) {
        let size = frontSize - depth * shrink
        rects.append(CGRect(x: front.maxX + depth * step - size, y: front.maxY + depth * step - size, width: size, height: size))
    }
    return rects
}

/// Shadow lengths are in pixels, not points, so they are scaled here.
func setShadow(_ context: CGContext, offset: CGFloat, blur: CGFloat, color: CGColor) {
    let scale = context.ctm.a
    context.setShadow(offset: CGSize(width: 0, height: -offset * scale), blur: blur * scale, color: color)
}

func drawVerticalGradient(_ context: CGContext, in rect: CGRect, colors: [CGColor], locations: [CGFloat]) {
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations)!
    context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.minY), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// A thin light edge inside the path, bright along the top and faint along the bottom.
func drawRim(_ context: CGContext, path: CGPath, rect: CGRect, width: CGFloat, topAlpha: CGFloat, bottomAlpha: CGFloat) {
    context.saveGState()
    context.addPath(path)
    context.clip()
    context.addPath(path)
    context.setLineWidth(2 * width)
    context.replacePathWithStrokedPath()
    context.clip()
    drawVerticalGradient(
        context,
        in: rect,
        colors: [CGColor(gray: 1, alpha: topAlpha), CGColor(gray: 1, alpha: 0), CGColor(gray: 1, alpha: 0), CGColor(gray: 1, alpha: bottomAlpha)],
        locations: [0, 0.4, 0.75, 1]
    )
    context.restoreGState()
}

func drawBody(_ context: CGContext) {
    let path = buildRoundedRectPath(bodyRect, cornerRadius: bodyCornerRadius)

    context.saveGState()
    setShadow(context, offset: bodyShadowOffset, blur: bodyShadowBlur, color: bodyShadowColor)
    context.addPath(path)
    context.setFillColor(bodyBottomColor)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(path)
    context.clip()
    drawVerticalGradient(context, in: bodyRect, colors: [bodyTopColor, bodyBottomColor], locations: [0, 1])
    let glow = CGGradient(colorsSpace: colorSpace, colors: [glowColor, glowColor.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
    context.drawRadialGradient(glow, startCenter: glowCenter, startRadius: 0, endCenter: glowCenter, endRadius: glowRadius, options: [])
    context.restoreGState()

    drawRim(context, path: path, rect: bodyRect, width: bodyRimWidth, topAlpha: bodyRimTopAlpha, bottomAlpha: bodyRimBottomAlpha)
}

/// What is already drawn, blurred, is the backdrop a glass tile shows through its tint.
func buildFrostedBackdrop(_ context: CGContext) -> CGImage {
    let drawn = context.makeImage()!
    let bounds = CGRect(x: 0, y: 0, width: drawn.width, height: drawn.height)
    let blurred = CIImage(cgImage: drawn).clampedToExtent().applyingGaussianBlur(sigma: tileFrostBlur * context.ctm.a).cropped(to: bounds)
    return imageContext.createCGImage(blurred, from: bounds)!
}

func drawGlassTile(_ context: CGContext, rect: CGRect, gradient: (top: CGColor, bottom: CGColor)) {
    let path = buildRoundedRectPath(rect, cornerRadius: rect.width * tileCornerRadiusRatio)
    let backdrop = buildFrostedBackdrop(context)

    context.saveGState()
    setShadow(context, offset: rect.height * tileShadowOffsetRatio, blur: rect.height * tileShadowBlurRatio, color: tileShadowColor)
    context.addPath(path)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(path)
    context.clip()
    context.draw(backdrop, in: CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
    drawVerticalGradient(context, in: rect, colors: [gradient.top, gradient.bottom], locations: [0, 1])
    drawVerticalGradient(context, in: rect, colors: [CGColor(gray: 1, alpha: tileSheenAlpha), CGColor(gray: 1, alpha: 0)], locations: [0, tileSheenReach])
    context.restoreGState()

    drawRim(context, path: path, rect: rect, width: rect.width * tileRimWidthRatio, topAlpha: tileRimTopAlpha, bottomAlpha: tileRimBottomAlpha)
}

func drawCommandSymbol(_ context: CGContext, on tile: CGRect) {
    let configuration = NSImage.SymbolConfiguration(pointSize: tile.height, weight: commandSymbolWeight)
    let symbol = NSImage(systemSymbolName: "command", accessibilityDescription: nil)!.withSymbolConfiguration(configuration)!
    let height = tile.height * commandSymbolHeightRatio
    let width = height * symbol.size.width / symbol.size.height
    let rect = CGRect(x: tile.midX - width / 2, y: tile.midY - height / 2, width: width, height: height)

    context.saveGState()
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    symbol.draw(in: rect)
    context.setBlendMode(.sourceIn)
    drawVerticalGradient(context, in: rect, colors: [commandTopColor, commandBottomColor], locations: [0, 1])
    context.endTransparencyLayer()
    context.restoreGState()
}

func drawIcon(_ context: CGContext, pixelSize: Int) {
    let isSmall = pixelSize <= smallIconMaxPixelSize
    let layout = isSmall ? smallTileLayout : largeTileLayout
    let tileRects = buildTileRects(frontSize: layout.frontSize, step: layout.step, shrink: layout.shrink)

    drawBody(context)
    for (rect, gradient) in zip(tileRects, tileGradients) {
        drawGlassTile(context, rect: rect, gradient: gradient)
    }

    if isSmall { return }
    drawCommandSymbol(context, on: tileRects.last!)
}

func renderIcon(pixelSize: Int) -> CGImage {
    let context = CGContext(data: nil, width: pixelSize, height: pixelSize, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: CGFloat(pixelSize) / canvasSize, y: CGFloat(pixelSize) / canvasSize)
    drawIcon(context, pixelSize: pixelSize)
    return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try! png.write(to: url)
}

if FileManager.default.fileExists(atPath: iconsetURL.path) {
    try! FileManager.default.removeItem(at: iconsetURL)
}
try! FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for entry in iconsetEntries {
    writePNG(renderIcon(pixelSize: entry.pixelSize), to: iconsetURL.appendingPathComponent("\(entry.name).png"))
}

let iconutil = try! Process.run(URL(fileURLWithPath: "/usr/bin/iconutil"), arguments: ["-c", "icns", iconsetURL.path, "-o", icnsURL.path])
iconutil.waitUntilExit()
precondition(iconutil.terminationStatus == 0, "iconutil failed")
print("wrote \(icnsURL.path)")
