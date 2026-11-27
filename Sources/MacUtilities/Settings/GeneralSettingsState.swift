import ApplicationServices
import Combine
import ServiceManagement

/// What the General pane shows besides the features: the Accessibility grant and the login item, both granted outside the app and so re-read on demand.
final class GeneralSettingsState: ObservableObject {
    @Published private(set) var isAccessibilityTrusted = AXIsProcessTrusted()
    @Published private(set) var loginItemStatus: SMAppService.Status

    private let loginItem: LoginItem

    init(loginItem: LoginItem) {
        self.loginItem = loginItem
        loginItemStatus = loginItem.status
    }

    func refresh() {
        isAccessibilityTrusted = AXIsProcessTrusted()
        loginItemStatus = loginItem.status
    }

    func setLaunchesAtLogin(_ enabled: Bool) {
        if enabled {
            try! loginItem.register()
        } else {
            try! loginItem.unregister()
        }

        loginItemStatus = loginItem.status
    }
}
