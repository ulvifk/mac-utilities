import AppKit
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

    /// An existing install has no record of a launch, so it counts as a first launch; one already launching at login is left alone.
    @Test
    func existingInstallWithTheLoginItemOnIsLeftAlone() {
        let loginItem = FakeLoginItem(status: .enabled)

        launch(loginItem: loginItem, isInstalled: true)
        loginItem.status = .notRegistered
        launch(loginItem: loginItem, isInstalled: true)

        #expect(loginItem.registerCount == 0, "A login item that was already on was registered again, or again on a later launch")
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

        #expect(firstInterface.generalSettingsOpenCount == 1, "A registration awaiting approval did not open General")
        #expect(secondInterface.generalSettingsOpenCount == 0, "A later launch opened General")
    }

    @Test
    func approvedRegistrationDoesNotOpenGeneral() {
        let interface = launch(loginItem: FakeLoginItem(), isInstalled: true)

        #expect(interface.generalSettingsOpenCount == 0)
    }

    @Test
    func onlyAppsFoldersCountAsInstalled() {
        let home = FileManager.default.homeDirectoryForCurrentUser

        #expect(isInApplicationsFolder(bundleURL: home.appendingPathComponent("Applications/MacUtilities.app", isDirectory: true)))
        #expect(isInApplicationsFolder(bundleURL: URL(fileURLWithPath: "/Applications/MacUtilities.app", isDirectory: true)))
        #expect(!isInApplicationsFolder(bundleURL: home.appendingPathComponent("git-repo/mac-utilities/MacUtilities.app", isDirectory: true)))
    }

    @discardableResult
    private func launch(loginItem: FakeLoginItem, isInstalled: Bool) -> FakeAppInterface {
        let interface = FakeAppInterface()
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
