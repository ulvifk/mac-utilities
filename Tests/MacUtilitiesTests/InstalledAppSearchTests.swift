import AppKit
import Testing
@testable import MacUtilities

struct InstalledAppSearchTests {
    private let apps = ["Safari", "Visual Studio Code", "Xcode"].map {
        InstalledApp(bundleIdentifier: "test.\($0)", name: $0, icon: NSImage())
    }

    @Test
    func testSearchMatchesAnywhereInTheNameIgnoringCase() {
        let names = getApps(in: apps, withNameContaining: "CODE").map(\.name)
        #expect(names == ["Visual Studio Code", "Xcode"])
    }

    @Test
    func testEmptySearchKeepsEveryApp() {
        let names = getApps(in: apps, withNameContaining: "").map(\.name)
        #expect(names == ["Safari", "Visual Studio Code", "Xcode"])
    }

    @Test
    func testSearchWithoutMatchesFindsNoApps() {
        #expect(getApps(in: apps, withNameContaining: "terminal").isEmpty)
    }
}
