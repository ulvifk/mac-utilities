import AppKit
import SwiftUI

private let menuItemTitle = "Keep awake"
private let activeSymbolName = "cup.and.saucer.fill"

/// Keeps the Mac awake from the menu bar: a power assertion and, when wanted, lid-closed sleep disabled through pmset; turns itself off after the set time.
final class KeepAwakeFeature: Feature {
    let identifier = "keep-awake"
    let displayName = "Keep Awake"
    let menuItems: [NSMenuItem]

    private let preferences = KeepAwakePreferences()
    private let menuItem = NSMenuItem(title: menuItemTitle, action: #selector(KeepAwakeFeature.toggle), keyEquivalent: "")
    private let setMenuBarSymbol: (String?) -> Void

    private var session: KeepAwakeSession?
    /// Refreshes the remaining time in the menu item and ends the session once its time is up.
    private var minuteTimer: Timer?

    init(setMenuBarSymbol: @escaping (String?) -> Void) {
        self.setMenuBarSymbol = setMenuBarSymbol
        menuItems = [menuItem]
        menuItem.target = self
    }

    func start() {}

    func stop() {
        if session == nil { return }

        deactivate()
    }

    func handle(type: CGEventType, event: CGEvent) -> Bool {
        return false
    }

    func buildSettingsView() -> AnyView {
        return AnyView(KeepAwakeSettingsView(preferences: preferences))
    }

    @objc private func toggle() {
        if session == nil {
            activate()
        } else {
            deactivate()
        }
    }

    private func activate() {
        session = KeepAwakeSession(preferences: preferences)
        minuteTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [unowned self] _ in self.handleMinutePassed() }

        menuItem.state = .on
        updateMenuItemTitle()
        setMenuBarSymbol(activeSymbolName)
    }

    private func deactivate() {
        session!.end()
        session = nil
        minuteTimer!.invalidate()
        minuteTimer = nil

        menuItem.state = .off
        menuItem.title = menuItemTitle
        setMenuBarSymbol(nil)
    }

    private func handleMinutePassed() {
        if isTimeUp() {
            deactivate()
            return
        }

        updateMenuItemTitle()
    }

    private func isTimeUp() -> Bool {
        guard let deactivationDate = session!.deactivationDate else { return false }
        return Date() >= deactivationDate
    }

    private func updateMenuItemTitle() {
        guard let deactivationDate = session!.deactivationDate else {
            menuItem.title = menuItemTitle
            return
        }

        menuItem.title = "\(menuItemTitle) (\(formatRemainingTime(until: deactivationDate)) left)"
    }

    private func formatRemainingTime(until date: Date) -> String {
        let minutes = Int((date.timeIntervalSinceNow / 60).rounded(.up))
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h \(minutes % 60) min"
    }
}
