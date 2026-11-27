import ServiceManagement
@testable import MacUtilities

/// Counts what is asked of the login item; registering moves it to statusAfterRegistering, as macOS would.
final class FakeLoginItem: LoginItem {
    var status: SMAppService.Status
    private let statusAfterRegistering: SMAppService.Status

    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    init(status: SMAppService.Status = .notRegistered, statusAfterRegistering: SMAppService.Status = .enabled) {
        self.status = status
        self.statusAfterRegistering = statusAfterRegistering
    }

    func register() throws {
        registerCount += 1
        status = statusAfterRegistering
    }

    func unregister() throws {
        unregisterCount += 1
        status = .notRegistered
    }
}
