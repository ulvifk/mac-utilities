import ServiceManagement
@testable import MacUtilities

/// No menu bar item and no window. Records the login item's status when launched, which is what a settings window built then would show,
/// and counts the requests to open General.
final class FakeAppInterface: AppInterface {
    private(set) var loginItemStatusAtLaunch: SMAppService.Status?
    private(set) var generalSettingsOpenCount = 0

    func launch(controller: AppController) {
        loginItemStatusAtLaunch = controller.loginItem.status
    }

    func openGeneralSettings() {
        generalSettingsOpenCount += 1
    }
}
