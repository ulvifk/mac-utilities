import AppKit
import Combine
import SwiftUI

// These collaborators keep the production feature's event handling isolated from apps, windows and preferences.
final class NSRunningApplication {
    static var activatedIdentifiers: [String] = []
    static var quitIdentifiers: [String] = []
    static var hiddenIdentifiers: [String] = []

    let bundleIdentifier: String?
    let processIdentifier: pid_t
    let localizedName: String? = "Test App"
    let isHidden = false

    init(index: Int) {
        bundleIdentifier = "test.app.\(index)"
        processIdentifier = pid_t(index)
    }

    func activate(options: AppKit.NSApplication.ActivationOptions) {
        Self.activatedIdentifiers.append(bundleIdentifier!)
    }

    func terminate() {
        Self.quitIdentifiers.append(bundleIdentifier!)
    }

    func hide() {
        Self.hiddenIdentifiers.append(bundleIdentifier!)
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
    static var instances: [SwitcherPanel] = []
    static var shownStates: [SwitcherState] = []
    static var updatedStates: [SwitcherState] = []
    static var glassUpdatedStates: [SwitcherState] = []
    static var feedback: [SwitcherFeedback] = []

    var onCellClicked: (Int) -> Void = { _ in }
    var onWidthDragged: (CGFloat) -> Void = { _ in }
    var ignoresMouseEvents = false
    var isVisible = false
    let frame = NSRect.zero
    let alphaValue: CGFloat = 1

    init() {
        Self.instances.append(self)
    }

    func show(state: SwitcherState, glassStore: GlassStore) {
        Self.shownStates.append(state)
        isVisible = true
    }

    func hide() {
        isVisible = false
    }

    func update(state: SwitcherState) { Self.updatedStates.append(state) }
    func updateGlass(state: SwitcherState, glassStore: GlassStore) { Self.glassUpdatedStates.append(state) }
    func resize(state: SwitcherState) {}
    func removeApp(at index: Int, state: SwitcherState) {}
    func showHintsAfterDelay() {}
    func showFeedback(_ feedback: SwitcherFeedback) { Self.feedback.append(feedback) }
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
    static var filterChanges: [Bool] = []

    private(set) var isFilterEnabled = false
    private var whitelist: Set<String> = []

    func getWhitelist() -> Set<String> { return whitelist }
    func isListed(_ identifier: String) -> Bool { return whitelist.contains(identifier) }
    func setFilterEnabled(_ enabled: Bool) {
        isFilterEnabled = enabled
        Self.filterChanges.append(enabled)
    }
    func setListed(_ identifier: String, _ listed: Bool) {
        if listed {
            whitelist.insert(identifier)
            return
        }

        whitelist.remove(identifier)
    }
}

final class BatchQuitStore {
    static var quitCount = 0
}

final class GlassStore: ObservableObject {
    static var stores: [String: GlassStore] = [:]

    init(keyPrefix: String, defaultDarkness: CGFloat) {
        Self.stores[keyPrefix] = self
    }
}

final class SwitcherCardStore: ObservableObject {
    static var stores: [String: SwitcherCardStore] = [:]

    var showsCards = false

    init(key: String) { Self.stores[key] = self }
}

final class PanelWidthStore {
    let width: CGFloat? = nil

    func setWidth(_ width: CGFloat) { fatalError("Unexpected preference change") }
}

struct AppWindow {
    static var windows: [AppWindow] = []
    static var raisedWindowIDs: [CGWindowID] = []

    let windowID: CGWindowID
    let title = "Test Window"

    func bringToFront() { Self.raisedWindowIDs.append(windowID) }
}

struct AppSwitcherSettingsView: View {
    let whitelistStore: WhitelistStore
    let batchQuitStore: BatchQuitStore
    let appGlassStore: GlassStore
    let windowGlassStore: GlassStore
    let appCardStore: SwitcherCardStore
    let appCardGlassStore: GlassStore
    let windowCardStore: SwitcherCardStore
    let windowCardGlassStore: GlassStore

    var body: some View { EmptyView() }
}

enum AppQueries {
    static var runningApps = 0
    static var appsWithWindows = 0
    static var windows = 0
}

func getRegularRunningApps() -> [NSRunningApplication] {
    AppQueries.runningApps += 1
    return RecentAppsTracker.apps
}
func getAppsWithWindows(_ apps: [NSRunningApplication]) -> [NSRunningApplication] {
    AppQueries.appsWithWindows += 1
    return apps
}
func getWindows(of app: NSRunningApplication) -> [AppWindow] {
    AppQueries.windows += 1
    return AppWindow.windows
}
func getAppName(_ app: NSRunningApplication) -> String { return app.localizedName! }
func runBatchQuit(_ store: BatchQuitStore) -> Int {
    BatchQuitStore.quitCount += 1
    return 2
}
func enableCursorChangesWhileInactive() {}
func captureThumbnails(of ids: [CGWindowID], completion: @escaping (CGWindowID, NSImage) -> Void) {
    if ids.isEmpty { return }

    ThumbnailRequest.requests.append(ThumbnailRequest(windowIDs: ids, completion: completion))
}
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

struct ThumbnailRequest {
    static var requests: [ThumbnailRequest] = []

    let windowIDs: [CGWindowID]
    let completion: (CGWindowID, NSImage) -> Void
}

let defaultGlassDarkness: CGFloat = 0.14
let defaultCardDarkness: CGFloat = 0.3
let defaultPanelWidthFraction: CGFloat = 0.7
let hintDelay: TimeInterval = 0.9
let glassPreviewDuration: TimeInterval = 1
let smokeCapturePath = "/unused"
