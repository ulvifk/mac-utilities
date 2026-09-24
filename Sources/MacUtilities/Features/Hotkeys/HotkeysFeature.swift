import AppKit
import SwiftUI

/// Global shortcuts that open or toggle apps, run commands and toggle keep-awake; a bound combo never reaches the focused app.
final class HotkeysFeature: Feature {
    let identifier = "hotkeys"
    let displayName = "Hotkeys"
    let menuItems: [NSMenuItem] = []

    private let store = HotkeyBindingsStore()
    private let toggleKeepAwake: () -> Void

    init(toggleKeepAwake: @escaping () -> Void) {
        self.toggleKeepAwake = toggleKeepAwake
    }

    func start() {}

    func stop() {}

    /// Runs the action off the tap; a held key repeats the press, and those repeats are swallowed without acting again.
    func handle(type: CGEventType, event: CGEvent) -> Bool {
        if type != .keyDown { return false }

        let combo = KeyCombo(tappedEvent: event)
        guard let binding = store.bindings.first(where: { $0.key == combo }) else { return false }

        if isAutorepeat(event) { return true }

        DispatchQueue.main.async { performHotkeyAction(binding.action, toggleKeepAwake: self.toggleKeepAwake) }
        return true
    }

    func buildSettingsView() -> AnyView {
        return AnyView(HotkeysSettingsView(store: store))
    }

    private func isAutorepeat(_ event: CGEvent) -> Bool {
        return event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    }
}
