import AppKit
import Combine
import SwiftUI

final class NSImage {
    init() {}
    init?(systemSymbolName: String, accessibilityDescription: String) {}
}

final class NSStatusBarButton {
    var target: AnyObject?
    var action: Selector?
    var image: NSImage?
}

final class NSStatusItem {
    static let variableLength: CGFloat = 0
    let button: NSStatusBarButton? = NSStatusBarButton()
}

final class NSStatusBar {
    static let system = NSStatusBar()
    func statusItem(withLength: CGFloat) -> NSStatusItem { NSStatusItem() }
}

final class Preferences {
    func isFeatureEnabled(_ identifier: String) -> Bool { identifier == "enabled" }
    func setFeatureEnabled(_ identifier: String, _ enabled: Bool) {}
}

final class EventTap {
    static var instance: EventTap!
    let isRunning = false
    private let handle: (CGEventType, CGEvent) -> Bool

    init(handle: @escaping (CGEventType, CGEvent) -> Bool) {
        self.handle = handle
        Self.instance = self
    }

    func start() {}

    func sendEvent() {
        _ = handle(.keyDown, CGEvent(source: nil)!)
    }
}

final class MenuBarPopover {
    init(rootView: MenuBarPopoverView, statusItemButton: NSStatusBarButton) {}
    func toggle() {}
    func close() {}
}

struct MenuBarPopoverView {
    let controller: AppController
}

final class SettingsWindow {
    init(controller: AppController) {}
    func showPane(_ identifier: String) {}
    func open() {}
}

let generalPaneIdentifier = "general"
func buildMenuBarGlyph() -> NSImage { NSImage() }
func requestAccessibilityTrust() {}
func runSettingsSmokeTestIfRequested(controller: AppController) {}
func runMenuBarSmokeTestIfRequested(controller: AppController) {}

final class DelayedFeature: Feature {
    let identifier: String
    let displayName = "Test feature"
    let summary = "Test feature"
    let iconSymbolName = "star"
    let iconGradient = Gradient(colors: [.orange])
    var stopCount = 0
    var eventCount = 0
    var cleanupCount = 0
    var didFinishCleanup = false

    init(identifier: String) {
        self.identifier = identifier
    }

    func start() {}
    func stop() { stopCount += 1 }
    func handle(type: CGEventType, event: CGEvent) -> Bool {
        eventCount += 1
        return false
    }
    func buildSettingsSections() -> AnyView { AnyView(EmptyView()) }
    func buildPopoverTile() -> AnyView? { nil }

    @MainActor func prepareForTermination() async {
        precondition(Thread.isMainThread)
        cleanupCount += 1
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                EventTap.instance.sendEvent()
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.02) {
                    continuation.resume()
                }
            }
        }
        didFinishCleanup = true
    }
}

let enabled = DelayedFeature(identifier: "enabled")
let disabled = DelayedFeature(identifier: "disabled")
let controller = AppController(features: [enabled, disabled])
let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
application.delegate = controller

let observation = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { _ in
    precondition(Thread.isMainThread)
    precondition(enabled.stopCount == 1, "Quit did not stop the enabled feature once")
    precondition(disabled.stopCount == 0, "Quit stopped an unstarted feature")
    precondition(enabled.cleanupCount == 1, "Quit did not clean up the enabled feature once")
    precondition(disabled.cleanupCount == 1, "Quit did not clean up the disabled feature once")
    precondition(enabled.didFinishCleanup, "Quit did not wait for enabled cleanup")
    precondition(disabled.didFinishCleanup, "Quit did not wait for disabled cleanup")
    precondition(enabled.eventCount == 1, "The stopped feature received events during Quit")
    precondition(disabled.eventCount == 0, "The disabled feature received events during Quit")
    print("PASS " + CommandLine.arguments[1])
    fflush(stdout)
}

let launchObservation = NotificationCenter.default.addObserver(forName: NSApplication.didFinishLaunchingNotification, object: application, queue: nil) { _ in
    DispatchQueue.main.async {
        EventTap.instance.sendEvent()
        precondition(enabled.eventCount == 1, "The enabled feature did not receive events before Quit")
        precondition(disabled.eventCount == 0, "A disabled feature received events before Quit")

        switch CommandLine.arguments[1] {
        case "dispatch": terminateApplication()
        case "task": Task { @MainActor in terminateApplication() }
        case "native":
            CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) {
                application.terminate(nil)
            }
        default: fatalError("Unknown termination context")
        }
    }
}
DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
    print("Timed out waiting for AppKit termination")
    fflush(stdout)
    _exit(3)
}
application.run()
