import AppKit
import QuartzCore

let smokeCapturePath = "/tmp/app-switcher-smoke.png"

/// Colorful window behind the panel, so the capture shows what the glass is blurring. APP_SWITCHER_SMOKE_DARK=1 makes it a dark gray-blue instead.
var captureBackdrop: NSWindow?

/// Opens a switcher panel once without a keyboard, prints its geometry, captures it to smokeCapturePath once the hints have come in and exits:
/// - APP_SWITCHER_SMOKE_INDEX picks the selected item, 1 by default
/// - APP_SWITCHER_SMOKE_FILTER=1 or 0 writes the filter preference first
/// - APP_SWITCHER_SMOKE_WINDOWS=1 lists the frontmost app's windows instead of the apps
final class AppSwitcherSmokeTest {
    private let panel: GlassSwitcherPanel
    private let settings: SwitcherSettings
    private let listLoader: SwitcherListLoader
    private let workspace: SwitcherWorkspace
    private let thumbnailCache: WindowThumbnailCache
    private let environment: [String: String]

    /// The shown one; nil until the panel shows.
    private var list: SwitcherList?
    /// Never renewed: the smoke test exits once it has captured the panel.
    private let session = SwitcherSession()

    init(panel: GlassSwitcherPanel, settings: SwitcherSettings, listLoader: SwitcherListLoader, workspace: SwitcherWorkspace,
         thumbnailCache: WindowThumbnailCache, environment: [String: String]) {
        self.panel = panel
        self.settings = settings
        self.listLoader = listLoader
        self.workspace = workspace
        self.thumbnailCache = thumbnailCache
        self.environment = environment
    }

    func run() {
        settings.whitelistStore.setFilterEnabled(environment["APP_SWITCHER_SMOKE_FILTER"] == "1")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showPanel()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2 + hintDelay) {
            self.printAndCapturePanel()
            exit(0)
        }
    }

    private func showPanel() {
        let listingWindows = environment["APP_SWITCHER_SMOKE_WINDOWS"] == "1"
        let loadedList = listingWindows ? listLoader.loadWindowList(of: workspace.getFrontmostApp()) : listLoader.loadAppList()
        let list = loadedList.selecting(Int(environment["APP_SWITCHER_SMOKE_INDEX"] ?? "1")!)

        self.list = list
        panel.show(state: buildState(list), glassStore: settings.getGlassStore(listingWindows: listingWindows))
        panel.showHintsAfterDelay()
        showCaptureBackdrop(behind: panel)

        guard case .windows(let windows) = list.items else { return }
        thumbnailCache.refresh(of: windows, session: session) { self.panel.update(state: self.buildState(list)) }
    }

    private func printAndCapturePanel() {
        let list = list!
        var appNames: [String] = []
        var windowTitles: [String] = []
        switch list.items {
        case .apps(let apps, _): appNames = apps.map { $0.name }
        case .windows(let windows): windowTitles = windows.map { $0.title }
        }

        print("smoke: frame=\(panel.frame) visible=\(panel.isVisible) alpha=\(panel.alphaValue) apps=\(appNames.count) windows=\(windowTitles.count) selected=\(list.selectedIndex)")
        print("smoke: candidates=\(appNames) windows=\(windowTitles) thumbnails=\(thumbnailCache.thumbnails.count)")
        writeCapture(around: panel, path: smokeCapturePath)
    }

    private func buildState(_ list: SwitcherList) -> SwitcherState {
        return settings.buildState(list: list, thumbnails: thumbnailCache.thumbnails)
    }
}

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
