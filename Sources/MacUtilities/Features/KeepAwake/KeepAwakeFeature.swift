import AppKit
import Combine
import SwiftUI

let keepAwakeSymbolName = "cup.and.saucer.fill"

/// Keeps the Mac awake from the menu bar popover: a power assertion and, when wanted, lid-closed sleep disabled through pmset; turns itself off
/// after the set time. Publishes its state to its tile.
final class KeepAwakeFeature: Feature, ObservableObject {
    private static let sleepRestorationRetryInterval: TimeInterval = 5

    let identifier = "keep-awake"
    let displayName = "Keep Awake"
    let summary = "Keeps the Mac awake from the menu bar, even with the lid closed."
    let iconSymbolName = keepAwakeSymbolName
    let iconGradient = Gradient(colors: [.orange, .brown])

    private let preferences = KeepAwakePreferences()
    private let setMenuBarSymbol: (String?) -> Void

    /// nil while off.
    @Published private(set) var session: KeepAwakeSession?
    /// Sudo refused pmset at the last turn-on, so nothing is held; until the next turn-on.
    @Published private(set) var isPmsetRefused = false
    @Published private(set) var isSleepRestorationRefused = false

    /// Ends the session at its deadline or retries failed sleep restoration.
    private var deactivation: DispatchWorkItem?

    init(setMenuBarSymbol: @escaping (String?) -> Void) {
        self.setMenuBarSymbol = setMenuBarSymbol
    }

    func start() {}

    func stop() {
        if session == nil { return }

        deactivate()
    }

    func handle(type: CGEventType, event: CGEvent) -> Bool {
        return false
    }

    func buildSettingsSections() -> AnyView {
        return AnyView(KeepAwakeSettingsView(preferences: preferences))
    }

    func buildPopoverTile() -> AnyView? {
        return AnyView(KeepAwakeTile(feature: self))
    }

    /// On for the remembered time, or off.
    func toggle() {
        if session == nil {
            activate()
        } else {
            deactivate()
        }
    }

    /// On for that long from now, starting over when it is on already; the time becomes the remembered one the toggle uses.
    func turnOn(for autoOff: KeepAwakeAutoOff) {
        preferences.setAutoOff(autoOff)

        if session != nil {
            let didDeactivate = deactivate()
            if !didDeactivate { return }
        }
        activate()
    }

    private func activate() {
        guard let session = KeepAwakeSession(preferences: preferences) else {
            isPmsetRefused = true
            return
        }

        self.session = session
        isPmsetRefused = false
        if let deactivationDate = session.deactivationDate {
            deactivation = scheduleDeactivation(at: deactivationDate)
        }

        setMenuBarSymbol(keepAwakeSymbolName)
    }

    @discardableResult
    private func deactivate() -> Bool {
        deactivation?.cancel()
        deactivation = nil

        let didRestoreSleep = session!.end()
        if !didRestoreSleep {
            isSleepRestorationRefused = true
            deactivation = scheduleDeactivation(at: Date(timeIntervalSinceNow: Self.sleepRestorationRetryInterval))
            return false
        }

        session = nil
        isSleepRestorationRefused = false

        setMenuBarSymbol(nil)
        return true
    }

    /// On the wall clock, so a Mac that slept past the date turns it off on waking.
    private func scheduleDeactivation(at date: Date) -> DispatchWorkItem {
        let deactivation = DispatchWorkItem { [unowned self] in self.deactivate() }
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + date.timeIntervalSinceNow, execute: deactivation)
        return deactivation
    }
}
