@testable import MacUtilities

/// No menu bar item and no window; counts the requests to open General.
final class FakeAppInterface: AppInterface {
    private(set) var generalSettingsOpenCount = 0

    func launch(controller: AppController) {}

    func openGeneralSettings() {
        generalSettingsOpenCount += 1
    }
}
