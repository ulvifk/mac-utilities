import AppKit
import QuartzCore

let smokeCapturePath = "/tmp/app-switcher-smoke.png"

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
