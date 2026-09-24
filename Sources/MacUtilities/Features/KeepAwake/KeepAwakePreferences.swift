import Combine
import Foundation

/// The auto-off timer and the lid switch, in UserDefaults; both apply the next time Keep awake is turned on.
final class KeepAwakePreferences: ObservableObject {
    private let autoOffKey = "keepAwakeAutoOff"
    private let lidClosedKey = "keepAwakeWithLidClosed"
    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [autoOffKey: KeepAwakeAutoOff.untilTurnedOff.rawValue, lidClosedKey: true])
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
}
