import Foundation
import ServiceManagement
@testable import MacUtilities

/// Counts what is asked of the login item. Registering moves it to statusAfterRegistering, as macOS would, or throws registrationError,
/// as macOS does when it refuses.
final class FakeLoginItem: LoginItem {
    var status: SMAppService.Status
    private let statusAfterRegistering: SMAppService.Status
    private let registrationError: Error?

    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    init(status: SMAppService.Status = .notRegistered, statusAfterRegistering: SMAppService.Status = .enabled, registrationError: Error? = nil) {
        self.status = status
        self.statusAfterRegistering = statusAfterRegistering
        self.registrationError = registrationError
    }

    func register() throws {
        registerCount += 1
        if let registrationError { throw registrationError }
        status = statusAfterRegistering
    }

    func unregister() throws {
        unregisterCount += 1
        status = .notRegistered
    }
}
