import AppKit
import Testing
@testable import MacUtilities

/// Launches the app with an enabled and a disabled feature, quits from the given context once launched, and checks both features as AppKit
/// is about to end the process, then ends it itself with checkedExitCode.
@MainActor final class TerminationScenario: NSObject {
    /// The process exits with this once the checks ran, so a quit that skipped them, which AppKit ends with 0, fails the test.
    nonisolated static let checkedExitCode: Int32 = 42

    private let context: TerminationContext
    private let eventTap = FakeEventTap()
    private let enabled: CleanupRecordingFeature
    private let disabled: CleanupRecordingFeature
    private let controller: AppController

    init(context: TerminationContext) {
        self.context = context
        enabled = CleanupRecordingFeature(identifier: "enabled", eventTap: eventTap)
        disabled = CleanupRecordingFeature(identifier: "disabled", eventTap: eventTap)
        controller = AppController(
            features: [enabled, disabled],
            preferences: buildPreferences(disabledFeatures: [disabled.identifier]),
            eventTap: eventTap,
            loginItem: FakeLoginItem(),
            isInstalled: false,
            interface: FakeAppInterface()
        )
    }

    func run() {
        let application = NSApplication.shared

        application.setActivationPolicy(.prohibited)
        application.delegate = controller
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidFinishLaunching), name: NSApplication.didFinishLaunchingNotification, object: application)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate), name: NSApplication.willTerminateNotification, object: application)

        application.run()
    }

    @objc private func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            self.eventTap.sendKeyPress()
            #expect(self.enabled.eventCount == 1, "The enabled feature did not receive events before Quit")
            #expect(self.disabled.eventCount == 0, "A disabled feature received events before Quit")

            self.quit()
        }
    }

    @objc private func applicationWillTerminate(_ notification: Notification) {
        #expect(enabled.stopCount == 1, "Quit did not stop the enabled feature once")
        #expect(disabled.stopCount == 0, "Quit stopped an unstarted feature")
        #expect(enabled.cleanupCount == 1, "Quit did not clean up the enabled feature once")
        #expect(disabled.cleanupCount == 1, "Quit did not clean up the disabled feature once")
        #expect(enabled.didFinishCleanup, "Quit did not wait for enabled cleanup")
        #expect(disabled.didFinishCleanup, "Quit did not wait for disabled cleanup")
        #expect(enabled.eventCount == 1, "The stopped feature received events during Quit")
        #expect(disabled.eventCount == 0, "The disabled feature received events during Quit")

        exit(Self.checkedExitCode)
    }

    private func quit() {
        switch context {
        case .dispatch:
            terminateApplication()
        case .task:
            Task { @MainActor in terminateApplication() }
        case .native:
            CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
