import AppKit
import Testing
@testable import MacUtilities

struct AppPickerStateTests {
    private let state = AppPickerState(apps: ["Safari", "Visual Studio Code", "Xcode"].map {
        InstalledApp(bundleIdentifier: "test.\($0)", name: $0, icon: NSImage())
    })

    @Test
    func testSearchMatchesAnywhereInTheNameIgnoringCase() {
        state.changeSearchText(to: "CODE")
        #expect(state.results.map(\.name) == ["Visual Studio Code", "Xcode"])
    }

    @Test
    func testSearchIgnoresSurroundingWhitespace() {
        state.changeSearchText(to: " code ")
        #expect(state.results.map(\.name) == ["Visual Studio Code", "Xcode"])
    }

    @Test
    func testEmptySearchListsEveryAppWithoutAHighlight() {
        state.changeSearchText(to: "")
        #expect(state.results.map(\.name) == ["Safari", "Visual Studio Code", "Xcode"])
        #expect(state.getHighlightedApp() == nil)
    }

    @Test
    func testWhitespaceOnlySearchListsEveryAppWithoutAHighlight() {
        state.changeSearchText(to: "  ")
        #expect(state.results.map(\.name) == ["Safari", "Visual Studio Code", "Xcode"])
        #expect(state.getHighlightedApp() == nil)
    }

    @Test
    func testSearchHighlightsTheFirstResult() {
        state.changeSearchText(to: "code")
        #expect(state.getHighlightedApp()?.name == "Visual Studio Code")
    }

    @Test
    func testSearchWithoutResultsHighlightsNothing() {
        state.changeSearchText(to: "terminal")
        #expect(state.results.isEmpty)
        #expect(state.highlightedIndex == nil)
    }

    @Test
    func testDownStopsAtTheLastResult() throws {
        state.changeSearchText(to: "a")
        state.moveHighlightDown()
        state.moveHighlightDown()
        try #require(state.highlightedIndex == 1)
        #expect(state.getHighlightedApp()?.name == "Visual Studio Code")
    }

    @Test
    func testUpStopsAtTheFirstResult() throws {
        state.changeSearchText(to: "a")
        state.moveHighlightDown()
        state.moveHighlightUp()
        state.moveHighlightUp()
        try #require(state.highlightedIndex == 0)
        #expect(state.getHighlightedApp()?.name == "Safari")
    }

    @Test
    func testDownWithoutAHighlightHighlightsTheFirstResult() {
        state.changeSearchText(to: "")
        state.moveHighlightDown()
        #expect(state.getHighlightedApp()?.name == "Safari")
    }

    @Test
    func testUpWithoutAHighlightHighlightsTheFirstResult() {
        state.changeSearchText(to: "")
        state.moveHighlightUp()
        #expect(state.getHighlightedApp()?.name == "Safari")
    }

    @Test
    func testMovingWithoutResultsHighlightsNothing() {
        state.changeSearchText(to: "terminal")
        state.moveHighlightDown()
        state.moveHighlightUp()
        #expect(state.highlightedIndex == nil)
    }

    @Test
    func testNarrowingTheSearchHighlightsTheFirstOfTheFewerResults() {
        state.changeSearchText(to: "a")
        state.moveHighlightDown()
        state.changeSearchText(to: "sa")
        #expect(state.getHighlightedApp()?.name == "Safari")
    }

    @Test
    func testWideningTheSearchHighlightsTheFirstOfTheMoreResults() {
        state.changeSearchText(to: "code")
        state.moveHighlightDown()
        state.changeSearchText(to: "c")
        #expect(state.results.map(\.name) == ["Visual Studio Code", "Xcode"])
        #expect(state.getHighlightedApp()?.name == "Visual Studio Code")
    }

    @Test
    func testHoverHighlightsTheHoveredResult() {
        state.changeSearchText(to: "")
        state.highlightResult(at: 2)
        #expect(state.getHighlightedApp()?.name == "Xcode")
    }

    @Test
    func testShowingClearsTheSearchAndTheHighlight() {
        state.changeSearchText(to: "code")
        state.show()
        #expect(state.isShown)
        #expect(state.searchText == "")
        #expect(state.getHighlightedApp() == nil)
    }
}
