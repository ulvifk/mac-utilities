import os

private let loggingSubsystem = "com.ulvifk.mac-utilities"

/// One unified-log category per feature, plus core. State transitions log at notice so they are stored on disk, failures at error.
extension Logger {
    static let core = Logger(subsystem: loggingSubsystem, category: "core")
    static let keepAwake = Logger(subsystem: loggingSubsystem, category: "keep-awake")
    static let hotkeys = Logger(subsystem: loggingSubsystem, category: "hotkeys")
    static let appSwitcher = Logger(subsystem: loggingSubsystem, category: "app-switcher")
    static let microphone = Logger(subsystem: loggingSubsystem, category: "microphone")
}
