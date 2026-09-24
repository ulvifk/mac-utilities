import AppKit
import QuartzCore

let smokeCapturePath = "/tmp/app-switcher-smoke.png"

/// Screen-region capture of our own windows. CGWindowListCreateImage is gone from the SDK but still in the dylib.
typealias CreateWindowImage = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?

func writeCapture(around window: NSWindow, path: String) {
    let margin: CGFloat = 40
    let frame = window.frame.insetBy(dx: -margin, dy: -margin)
    let flipped = CGRect(
        x: frame.minX,
        y: NSScreen.screens[0].frame.height - frame.maxY,
        width: frame.width,
        height: frame.height
    )

    let onScreenOnly: UInt32 = 1 << 0
    let everyWindow: UInt32 = 0
    let bestResolution: UInt32 = 1 << 3

    let symbol = dlsym(dlopen(nil, RTLD_NOW), "CGWindowListCreateImage")!
    let createImage = unsafeBitCast(symbol, to: CreateWindowImage.self)
    let image = createImage(flipped, onScreenOnly, everyWindow, bestResolution)!.takeRetainedValue()
    let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!

    try! png.write(to: URL(fileURLWithPath: path))
    print("smoke: capture \(image.width)x\(image.height) -> \(path)")
}

/// Colorful window behind the panel, so the capture shows what the glass is blurring. APP_SWITCHER_SMOKE_DARK=1 makes it a dark gray-blue instead.
var captureBackdrop: NSWindow?

func getCaptureBackdropColors() -> [CGColor] {
    if ProcessInfo.processInfo.environment["APP_SWITCHER_SMOKE_DARK"] == "1" {
        return [NSColor(srgbRed: 0x1b / 255, green: 0x1d / 255, blue: 0x24 / 255, alpha: 1).cgColor, NSColor(srgbRed: 0x2a / 255, green: 0x2f / 255, blue: 0x3a / 255, alpha: 1).cgColor]
    }

    return [NSColor.systemPink.cgColor, NSColor.systemOrange.cgColor, NSColor.white.cgColor, NSColor.systemTeal.cgColor, NSColor.systemIndigo.cgColor]
}

func showCaptureBackdrop(behind window: NSWindow) {
    let backdrop = NSWindow(contentRect: window.frame.insetBy(dx: -80, dy: -80), styleMask: .borderless, backing: .buffered, defer: false)
    let gradient = CAGradientLayer()

    gradient.frame = NSRect(origin: .zero, size: backdrop.frame.size)
    gradient.colors = getCaptureBackdropColors()
    gradient.startPoint = CGPoint(x: 0, y: 1)
    gradient.endPoint = CGPoint(x: 1, y: 0)

    backdrop.contentView!.wantsLayer = true
    backdrop.contentView!.layer!.addSublayer(gradient)
    backdrop.level = .normal
    backdrop.orderFrontRegardless()
    captureBackdrop = backdrop
}
