import Testing
@testable import MacUtilities

/// The "Launch at login" switch registers and unregisters the login item and shows the status it lands on.
struct GeneralSettingsStateTests {
    @Test
    func switchRegistersAndUnregistersTheLoginItem() {
        let loginItem = FakeLoginItem(statusAfterRegistering: .requiresApproval)
        let state = GeneralSettingsState(loginItem: loginItem)

        state.setLaunchesAtLogin(true)
        #expect(loginItem.registerCount == 1, "Switching on did not register the login item")
        #expect(state.loginItemStatus == .requiresApproval, "The switch does not show the status registering landed on")

        state.setLaunchesAtLogin(false)
        #expect(loginItem.unregisterCount == 1, "Switching off did not unregister the login item")
        #expect(state.loginItemStatus == .notRegistered)
    }

    @Test
    func refreshRereadsTheLoginItem() {
        let loginItem = FakeLoginItem()
        let state = GeneralSettingsState(loginItem: loginItem)

        loginItem.status = .enabled
        state.refresh()

        #expect(state.loginItemStatus == .enabled, "Approving under Login Items did not show after a refresh")
    }
}
