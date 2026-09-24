import Foundation

/// How long Keep awake stays on before turning itself off.
enum KeepAwakeAutoOff: String, CaseIterable {
    case thirtyMinutes
    case oneHour
    case twoHours
    case untilTurnedOff

    var title: String {
        switch self {
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        case .untilTurnedOff: return "Until turned off"
        }
    }

    var duration: TimeInterval? {
        switch self {
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        case .untilTurnedOff: return nil
        }
    }
}
