import AppKit
import Combine
import SwiftUI

// These collaborators keep the production feature's event handling isolated from apps, windows and preferences.
final class NSRunningApplication {
    let bundleIdentifier: String?
    let processIdentifier: pid_t
    let localizedName: String? = "Test App"
    let isHidden = false

    init(index: Int) {
        bundleIdentifier = "test.app.\(index)"
        processIdentifier = pid_t(index)
    }

    func activate(options: AppKit.NSApplication.ActivationOptions) {
        fatalError("Opening tests must not activate apps")
    }

    func terminate() {
        fatalError("Opening tests must not quit apps")
    }

    func hide() {
        fatalError("Opening tests must not hide apps")
    }
}

final class NSWorkspace {
    static let shared = NSWorkspace()
    static let didTerminateApplicationNotification = Notification.Name("test.terminated")
    static let didHideApplicationNotification = Notification.Name("test.hidden")
    static let didUnhideApplicationNotification = Notification.Name("test.unhidden")
    static let applicationUserInfoKey = "test.app"

    let notificationCenter = NotificationCenter()
    let frontmostApplication: NSRunningApplication? = NSRunningApplication(index: 0)
}

final class NSScreen {
    static let main: NSScreen? = NSScreen()

    let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
}

final class SwitcherPanel {
    static var shownStates: [SwitcherState] = []

    var onCellClicked: (Int) -> Void = { _ in }
    var onWidthDragged: (CGFloat) -> Void = { _ in }
    var ignoresMouseEvents = false
    var isVisible = false
    let frame = NSRect.zero
    let alphaValue: CGFloat = 1

    func show(state: SwitcherState, glassStore: GlassStore) {
        Self.shownStates.append(state)
        isVisible = true
    }

    func hide() {
        isVisible = false
    }

    func update(state: SwitcherState) {}
    func resize(state: SwitcherState) {}
    func removeApp(at index: Int, state: SwitcherState) {}
    func showHintsAfterDelay() {}
    func showFeedback(_ feedback: SwitcherFeedback) {}
}

final class RecentAppsTracker {
    static var apps: [NSRunningApplication] = []

    var bundleIdentifiers: [String] {
        return Self.apps.map { $0.bundleIdentifier! }
    }

    func start() {}
    func stop() {}
}

final class WhitelistStore {
    let isFilterEnabled = false

    func getWhitelist() -> Set<String> { return [] }
    func isListed(_ identifier: String) -> Bool { return false }
    func setFilterEnabled(_ enabled: Bool) { fatalError("Unexpected preference change") }
    func setListed(_ identifier: String, _ listed: Bool) { fatalError("Unexpected preference change") }
}

final class BatchQuitStore {}

final class GlassStore: ObservableObject {
    init(keyPrefix: String, defaultDarkness: CGFloat) {}
}

final class WindowCardStore: ObservableObject {
    let showsCards = false
}

final class PanelWidthStore {
    let width: CGFloat? = nil

    func setWidth(_ width: CGFloat) { fatalError("Unexpected preference change") }
}

struct AppWindow {
    static var windows: [AppWindow] = []

    let windowID: CGWindowID
    let title = "Test Window"

    func bringToFront() { fatalError("Opening tests must not raise windows") }
}

struct AppSwitcherSettingsView: View {
    let whitelistStore: WhitelistStore
    let batchQuitStore: BatchQuitStore
    let appGlassStore: GlassStore
    let windowGlassStore: GlassStore
    let windowCardStore: WindowCardStore
    let windowCardGlassStore: GlassStore

    var body: some View { EmptyView() }
}

func getRegularRunningApps() -> [NSRunningApplication] { return RecentAppsTracker.apps }
func getAppsWithWindows(_ apps: [NSRunningApplication]) -> [NSRunningApplication] { return apps }
func getWindows(of app: NSRunningApplication) -> [AppWindow] { return AppWindow.windows }
func getAppName(_ app: NSRunningApplication) -> String { return app.localizedName! }
func runBatchQuit(_ store: BatchQuitStore) -> Int { fatalError("Opening tests must not quit apps") }
func enableCursorChangesWhileInactive() {}
func captureThumbnails(of ids: [CGWindowID], completion: (CGWindowID, NSImage) -> Void) {}
func showCaptureBackdrop(behind panel: SwitcherPanel) {}
func writeCapture(around panel: SwitcherPanel, path: String) {}

func getVisualColumn(index: Int, cellCount: Int, cellsPerRow: Int) -> CGFloat {
    return CGFloat(index % cellsPerRow)
}

struct SwitcherCellMetrics {
    let hintBandHeight: CGFloat = 28

    func getCellCount(forPanelWidth width: CGFloat) -> CGFloat { return width / 100 }
    func getRowCount(forPanelHeight height: CGFloat) -> CGFloat { return height / 100 }
}

func getCellMetrics(listingWindows: Bool) -> SwitcherCellMetrics { return SwitcherCellMetrics() }

enum SwitcherFeedback {
    case addedToWhitelist
    case removedFromWhitelist
    case showingWhitelist
    case showingAllApps
    case noWhitelistedApps
    case hidden
    case quittingApp(name: String)
    case quittingApps(count: Int)
}

let defaultGlassDarkness: CGFloat = 0.14
let defaultWindowCardDarkness: CGFloat = 0.3
let defaultPanelWidthFraction: CGFloat = 0.7
let hintDelay: TimeInterval = 0.9
let glassPreviewDuration: TimeInterval = 1
let smokeCapturePath = "/unused"
