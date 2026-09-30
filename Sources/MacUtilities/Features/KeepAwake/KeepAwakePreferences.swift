import Combine
import Foundation

/// Keep Awake settings stored in UserDefaults.
final class KeepAwakePreferences: ObservableObject {
    private let autoOffKey = "keepAwakeAutoOff"
    private let lidClosedKey = "keepAwakeWithLidClosed"
    private let powerOnlyKey = "keepAwakeOnlyWhileConnectedToPower"
    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            autoOffKey: KeepAwakeAutoOff.untilTurnedOff.rawValue,
            lidClosedKey: true,
            powerOnlyKey: false
        ])
    }

    var autoOff: KeepAwakeAutoOff {
        return KeepAwakeAutoOff(rawValue: defaults.string(forKey: autoOffKey)!)!
    }

    func setAutoOff(_ autoOff: KeepAwakeAutoOff) {
        objectWillChange.send()
        defaults.set(autoOff.rawValue, forKey: autoOffKey)
    }

    var keepsAwakeWithLidClosed: Bool {
        return defaults.bool(forKey: lidClosedKey)
    }

    func setKeepsAwakeWithLidClosed(_ enabled: Bool) {
        objectWillChange.send()
        defaults.set(enabled, forKey: lidClosedKey)
    }

    var onlyWhileConnectedToPower: Bool {
        return defaults.bool(forKey: powerOnlyKey)
    }

    func setOnlyWhileConnectedToPower(_ enabled: Bool) {
        objectWillChange.send()
        defaults.set(enabled, forKey: powerOnlyKey)
    }
}
