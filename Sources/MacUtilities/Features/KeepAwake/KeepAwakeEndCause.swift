/// Why a Keep Awake session ends or its request is dropped.
enum KeepAwakeEndCause: String {
    case toggledOff = "toggled off"
    case deadlineReached = "deadline reached"
    case notConnectedToPower = "not connected to power"
    case replaced = "replaced by a new session"
    case featureSwitchedOff = "feature switched off"
    case quit
    case activationRefused = "activation refused"
}
