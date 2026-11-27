import ServiceManagement

/// The app's own login item, which macOS lists under System Settings > General > Login Items. main.swift passes SMAppService.mainApp.
protocol LoginItem: AnyObject {
    var status: SMAppService.Status { get }

    /// A self-signed app lands on requiresApproval until the user allows it under Login Items.
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItem {}

extension SMAppService.Status {
    /// Registered, whether or not the user has approved it yet.
    var isRegistered: Bool {
        if self == .enabled { return true }
        if self == .requiresApproval { return true }
        return false
    }

    var logDescription: String {
        switch self {
        case .notRegistered: return "not registered"
        case .enabled: return "enabled"
        case .requiresApproval: return "requires approval"
        case .notFound: return "not found"
        @unknown default: return "unknown (\(rawValue))"
        }
    }
}
