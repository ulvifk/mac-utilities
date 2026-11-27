import ServiceManagement
@testable import MacUtilities

/// No menu bar item and no window. Like the real interface it receives the login item; it records its status when launched, which is what
/// a settings window built then would show, and counts the requests to open General.
final class FakeAppInterface: AppInterface {
    private let loginItem: LoginItem

    private(set) var loginItemStatusAtLaunch: SMAppService.Status?
    private(set) var generalSettingsOpenCount = 0

    init(loginItem: LoginItem) {
        self.loginItem = loginItem
    }

    func launch(controller: AppController) {
        loginItemStatusAtLaunch = loginItem.status
    }

    func openGeneralSettings() {
        generalSettingsOpenCount += 1
    }
}
