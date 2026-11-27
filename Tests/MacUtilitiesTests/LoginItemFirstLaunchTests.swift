import AppKit
import ServiceManagement
import Testing
@testable import MacUtilities

/// The installed app registers its login item on its first launch and never again, so an opt-out sticks. Each launch builds a new controller
/// on the same defaults domain, as each launch of the app loads the stored values anew.
@MainActor
final class LoginItemFirstLaunchTests {
    private let defaults = TestDefaults()

    deinit {
        defaults.remove()
    }

    @Test
    func firstLaunchRegistersTheLoginItem() {
        let loginItem = FakeLoginItem()

        launch(loginItem: loginItem, isInstalled: true)

        #expect(loginItem.registerCount == 1, "The first launch did not register the login item once")
    }

    @Test
    func secondLaunchDoesNotRegisterAgain() {
        let loginItem = FakeLoginItem()

        launch(loginItem: loginItem, isInstalled: true)
        loginItem.status = .notRegistered
        launch(loginItem: loginItem, isInstalled: true)

        #expect(loginItem.registerCount == 1, "A later launch registered the login item again")
    }

    @Test
    func optOutSticksAcrossLaunches() {
        let loginItem = FakeLoginItem()

        launch(loginItem: loginItem, isInstalled: true)
        GeneralSettingsState(loginItem: loginItem).setLaunchesAtLogin(false)
        launch(loginItem: loginItem, isInstalled: true)

        #expect(loginItem.status == .notRegistered, "The next launch undid switching the login item off")
        #expect(loginItem.registerCount == 1)
    }

    /// An existing install has no record of a launch, so it counts as a first launch; a login item already registered is left alone, and
    /// one awaiting approval, which may be the user's own switch-off under Login Items, does not open General.
    @Test(arguments: [SMAppService.Status.enabled, .requiresApproval])
    func existingInstallWithTheLoginItemAlreadyRegisteredIsLeftAlone(status: SMAppService.Status) {
        let loginItem = FakeLoginItem(status: status)

        let firstInterface = launch(loginItem: loginItem, isInstalled: true)
        loginItem.status = .notRegistered
        let secondInterface = launch(loginItem: loginItem, isInstalled: true)

        #expect(loginItem.registerCount == 0, "A login item that was already on was registered again, or again on a later launch")
        #expect(firstInterface.generalSettingsOpenCount == 0, "A login item registered before this launch opened General")
        #expect(secondInterface.generalSettingsOpenCount == 0)
    }

    @Test
    func failedRegistrationIsNotRetried() {
        let loginItem = FakeLoginItem(registrationError: CocoaError(.featureUnsupported))

        let firstInterface = launch(loginItem: loginItem, isInstalled: true)
        launch(loginItem: loginItem, isInstalled: true)

        #expect(firstInterface.generalSettingsOpenCount == 0, "A failed registration opened General")
        #expect(loginItem.registerCount == 1, "A later launch retried the failed registration")
    }

    /// The smoke runs launch the development build from the build folder.
    @Test
    func developmentBuildNeitherRegistersNorUsesUpTheFirstLaunch() {
        let loginItem = FakeLoginItem()

        launch(loginItem: loginItem, isInstalled: false)
        #expect(loginItem.registerCount == 0, "A development build registered the login item")

        launch(loginItem: loginItem, isInstalled: true)
        #expect(loginItem.registerCount == 1, "A development build's launch used up the installed app's first launch")
    }

    @Test
    func firstLaunchAwaitingApprovalOpensGeneral() {
        let loginItem = FakeLoginItem(statusAfterRegistering: .requiresApproval)

        let firstInterface = launch(loginItem: loginItem, isInstalled: true)
        let secondInterface = launch(loginItem: loginItem, isInstalled: true)

        #expect(firstInterface.loginItemStatusAtLaunch == .requiresApproval, "The interface launched before registering, so General showed it off")
        #expect(firstInterface.generalSettingsOpenCount == 1, "A registration awaiting approval did not open General")
        #expect(secondInterface.generalSettingsOpenCount == 0, "A later launch opened General")
    }

    @Test
    func approvedRegistrationDoesNotOpenGeneral() {
        let interface = launch(loginItem: FakeLoginItem(), isInstalled: true)

        #expect(interface.generalSettingsOpenCount == 0)
    }

    @discardableResult
    private func launch(loginItem: FakeLoginItem, isInstalled: Bool) -> FakeAppInterface {
        let interface = FakeAppInterface(loginItem: loginItem)
        let controller = AppController(
            features: [],
            preferences: Preferences(defaults: defaults.buildUserDefaults()),
            eventTap: FakeEventTap(),
            loginItem: loginItem,
            isInstalled: isInstalled,
            interface: interface
        )

        controller.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        return interface
    }
}
