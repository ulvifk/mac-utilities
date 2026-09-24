import AppKit

/// Screen-region capture of our own windows, for the smoke tests. CGWindowListCreateImage is gone from the SDK but still in the dylib.
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
