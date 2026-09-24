import ApplicationServices
import Combine
import ServiceManagement

/// What the General tab shows besides the feature switches: the Accessibility grant and the login item, re-read on demand.
final class GeneralSettingsState: ObservableObject {
    @Published private(set) var isAccessibilityTrusted = AXIsProcessTrusted()
    @Published private(set) var loginItemStatus = SMAppService.mainApp.status

    func refreshAccessibilityTrust() {
        isAccessibilityTrusted = AXIsProcessTrusted()
    }

    /// Registering a self-signed app lands on requiresApproval until the user allows it under Login Items.
    func setLaunchesAtLogin(_ enabled: Bool) {
        if enabled {
            try! SMAppService.mainApp.register()
        } else {
            try! SMAppService.mainApp.unregister()
        }

        loginItemStatus = SMAppService.mainApp.status
    }
}
