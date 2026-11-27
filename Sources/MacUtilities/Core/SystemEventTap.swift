import CoreGraphics

/// The session-wide CoreGraphics tap. Starting it first asks for Accessibility, which the tap needs. macOS disables a tap whose callback is
/// slow; this one re-enables itself when that happens.
final class SystemEventTap: EventTap {
    private var handle: ((CGEventType, CGEvent) -> Bool)!
    private var tap: CFMachPort?

    var isRunning: Bool {
        return tap != nil
    }

    func start(handle: @escaping (CGEventType, CGEvent) -> Bool) {
        self.handle = handle
        requestAccessibilityTrust()

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: handleTappedEvent,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else {
            print("Could not create the event tap: every feature is off until Accessibility permission is granted.")
            return
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    fileprivate func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if isTapDisabled(type) {
            CGEvent.tapEnable(tap: tap!, enable: true)
            print("event tap re-enabled after \(type)")
            return Unmanaged.passUnretained(event)
        }

        if handle(type, event) {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func isTapDisabled(_ type: CGEventType) -> Bool {
        if type == .tapDisabledByTimeout { return true }
        if type == .tapDisabledByUserInput { return true }

        return false
    }
}

private func handleTappedEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    let tap = Unmanaged<SystemEventTap>.fromOpaque(userInfo!).takeUnretainedValue()
    return tap.handleEvent(type: type, event: event)
}
