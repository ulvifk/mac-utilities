import AppKit
import Testing
@testable import MacUtilities

/// A started App Switcher on fake apps, windows, screen and panels, its settings in a defaults domain of its own, with the key presses and
/// waits the scenarios are written in.
@MainActor
final class AppSwitcherTestHarness {
    let workspace: SwitcherFakeWorkspace
    let screen = SwitcherFakeScreen()
    let log = SwitcherPanelLog()
    let panel: SwitcherFakePanel
    let previewPanel: SwitcherFakePanel
    let settingsWindow: SwitcherTestSettingsWindow
    let settings: SwitcherSettings
    let feature: AppSwitcherFeature

    private let defaults = TestDefaults()

    /// That many running apps, each with a window, all activated in order.
    init(itemCount: Int = 3) {
        _ = NSApplication.shared.setActivationPolicy(.prohibited)

        workspace = SwitcherFakeWorkspace(itemCount: itemCount)
        panel = SwitcherFakePanel(log: log)
        previewPanel = SwitcherFakePanel(log: log)
        settingsWindow = SwitcherTestSettingsWindow(contentRect: NSRect(x: 360, y: 180, width: 720, height: 540), styleMask: .titled,
                                                    backing: .buffered, defer: false)
        settings = AppSwitcherFeatureFactory.buildSettings(defaults: defaults.buildUserDefaults())
        feature = AppSwitcherFeatureFactory.buildFeature(
            settings: settings, workspace: workspace, screen: screen, panel: panel, previewPanel: previewPanel, environment: [:]
        )

        feature.start()
    }

    /// Stops the feature, lets its queued work run out and drops the defaults domain.
    func finish() async {
        feature.stop(because: .switchedOff)
        await drainMainQueue()
        defaults.remove()
    }

    /// A press the switcher must swallow.
    func press(_ keyCode: Int64, modifiers: CGEventFlags = .maskCommand, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(sendKeyDown(keyCode, modifiers: modifiers), "Shortcut \(keyCode) was not handled", sourceLocation: sourceLocation)
    }

    /// Whether the switcher swallowed the press; false passes it on to the focused app.
    func sendKeyDown(_ keyCode: Int64, modifiers: CGEventFlags) -> Bool {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true)!
        event.flags = modifiers

        return feature.handle(type: .keyDown, event: event)
    }

    func releaseCommand(sourceLocation: SourceLocation = #_sourceLocation) {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)!
        event.flags = []

        #expect(!feature.handle(type: .flagsChanged, event: event), "Command release must pass through", sourceLocation: sourceLocation)
    }

    /// Runs what the main queue holds now, then what that work queued in turn.
    func drainMainQueue() async {
        for _ in 0..<2 {
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }

    /// The settings pane open and focused with Show preview checked.
    func showPreview(listingWindows: Bool = false) async {
        feature.settingsWindowChanged(settingsWindow)
        settings.previewStore.isListingWindows = listingWindows
        await drainMainQueue()
        settings.previewStore.isShown = true
        await drainMainQueue()
    }

    func setPreviewMode(listingWindows: Bool) async {
        settings.previewStore.isListingWindows = listingWindows
        await drainMainQueue()
    }

    func expectNoActivation(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(workspace.activatedBundleIdentifiers.isEmpty, "Unexpected app activation", sourceLocation: sourceLocation)
        #expect(workspace.raisedWindowIDs.isEmpty, "Unexpected window activation", sourceLocation: sourceLocation)
    }

    func expectActivation(listingWindows: Bool, selection: Int, sourceLocation: SourceLocation = #_sourceLocation) {
        if listingWindows {
            #expect(workspace.raisedWindowIDs == [CGWindowID(selection)], "Wrong window activated", sourceLocation: sourceLocation)
            #expect(workspace.activatedBundleIdentifiers.isEmpty, "Window switching activated all app windows", sourceLocation: sourceLocation)
            return
        }

        #expect(workspace.activatedBundleIdentifiers == ["test.app.\(selection)"], "Wrong app activated", sourceLocation: sourceLocation)
        #expect(workspace.raisedWindowIDs.isEmpty, "App switching raised a window", sourceLocation: sourceLocation)
    }
}

extension SwitcherState {
    var bundleIdentifiers: [String] {
        guard case .apps(let apps, _) = list.items else { return [] }
        return apps.map { $0.bundleIdentifier }
    }

    var windowIDs: [CGWindowID] {
        guard case .windows(let windows, _) = list.items else { return [] }
        return windows.map { $0.windowID }
    }
}
