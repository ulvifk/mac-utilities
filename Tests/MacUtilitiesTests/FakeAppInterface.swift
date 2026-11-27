@testable import MacUtilities

/// No menu bar item and no window.
final class FakeAppInterface: AppInterface {
    func launch(controller: AppController) {}
}
