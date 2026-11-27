import CoreGraphics
@testable import MacUtilities

/// Never running, like a tap macOS refused; sendKeyPress plays the tap delivering a key press to the controller.
final class FakeEventTap: EventTap {
    let isRunning = false

    private var handle: ((CGEventType, CGEvent) -> Bool)!

    func start(handle: @escaping (CGEventType, CGEvent) -> Bool) {
        self.handle = handle
    }

    func sendKeyPress() {
        _ = handle(.keyDown, CGEvent(source: nil)!)
    }
}
