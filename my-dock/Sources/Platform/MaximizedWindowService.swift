import AppKit
import ApplicationServices

final class MaximizedWindowService {
    private static let applicationNotifications = [kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification, kAXWindowCreatedNotification]
    private static let windowNotifications = [kAXMovedNotification, kAXResizedNotification]
    private static let adjustmentDelay: TimeInterval = 0.15

    private var area: MaximizedWindowArea?
    private var processID: pid_t?
    private var application: AXUIElement?
    private var observer: AXObserver?
    private var observedWindow: AXUIElement?
    private var pendingAdjustment: DispatchWorkItem?

    func update(area: MaximizedWindowArea?) {
        self.area = area
        if !AXIsProcessTrusted() {
            stopObserving()
            return
        }
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return }
        if !isEligibleApplication(frontmost) { return }
        if processID != frontmost.processIdentifier { observeApplication(frontmost.processIdentifier) }
        observeFocusedWindow()
        scheduleAdjustment()
    }

    func stopObserving() {
        pendingAdjustment?.cancel()
        pendingAdjustment = nil
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        application = nil
        observedWindow = nil
        processID = nil
    }

    private func scheduleAdjustment() {
        pendingAdjustment?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.adjustFocusedWindow() }
        pendingAdjustment = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.adjustmentDelay, execute: work)
    }

    private func observeApplication(_ pid: pid_t) {
        stopObserving()
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15)
        var newObserver: AXObserver?
        let result = AXObserverCreate(pid, { _, _, _, context in
            guard let context else { return }
            let service = Unmanaged<MaximizedWindowService>.fromOpaque(context).takeUnretainedValue()
            service.scheduleAdjustment()
        }, &newObserver)
        if result != .success { return }

        application = app
        processID = pid
        observer = newObserver!
        let context = Unmanaged.passUnretained(self).toOpaque()
        for name in Self.applicationNotifications {
            AXObserverAddNotification(observer!, app, name as CFString, context)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer!), .commonModes)
    }

    private func observeFocusedWindow() {
        guard let application, let observer else { return }
        let focusedWindow = getAttribute(application, kAXFocusedWindowAttribute) as! AXUIElement?
        if focusedWindow == observedWindow { return }
        if let observedWindow {
            for name in Self.windowNotifications {
                AXObserverRemoveNotification(observer, observedWindow, name as CFString)
            }
        }
        observedWindow = focusedWindow
        guard let focusedWindow else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        for name in Self.windowNotifications {
            AXObserverAddNotification(observer, focusedWindow, name as CFString, context)
        }
    }

    private func adjustFocusedWindow() {
        pendingAdjustment = nil
        guard let area else { return }
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return }
        if frontmost.processIdentifier != processID { return }
        if NSEvent.pressedMouseButtons != 0 {
            scheduleAdjustment()
            return
        }
        observeFocusedWindow()
        guard let window = observedWindow else { return }
        if !isResizableWindow(window) { return }
        guard let frame = getFrame(window) else { return }
        let screenFrame = area.convertScreenCoordinates(frame)
        guard let adjustedFrame = area.getAdjustedFrame(screenFrame) else { return }

        var size = adjustedFrame.size
        let value = AXValueCreate(.cgSize, &size)!
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
    }

    private func isEligibleApplication(_ app: NSRunningApplication) -> Bool {
        if app.activationPolicy != .regular { return false }
        if app.isTerminated { return false }
        return app.processIdentifier != ProcessInfo.processInfo.processIdentifier
    }

    private func isResizableWindow(_ window: AXUIElement) -> Bool {
        if getAttribute(window, kAXSubroleAttribute) as? String != kAXStandardWindowSubrole { return false }
        if getAttribute(window, kAXMinimizedAttribute) as? Bool == true { return false }
        if getAttribute(window, "AXFullScreen") as? Bool == true { return false }
        var isSettable = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &isSettable) != .success { return false }
        return isSettable.boolValue
    }

    private func getFrame(_ window: AXUIElement) -> CGRect? {
        guard let positionValue = getAttribute(window, kAXPositionAttribute) else { return nil }
        guard let sizeValue = getAttribute(window, kAXSizeAttribute) else { return nil }
        if CFGetTypeID(positionValue) != AXValueGetTypeID() { return nil }
        if CFGetTypeID(sizeValue) != AXValueGetTypeID() { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        if !AXValueGetValue(positionValue as! AXValue, .cgPoint, &position) { return nil }
        if !AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) { return nil }
        return CGRect(origin: position, size: size)
    }

    private func getAttribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, name as CFString, &value) != .success { return nil }
        return value
    }
}
