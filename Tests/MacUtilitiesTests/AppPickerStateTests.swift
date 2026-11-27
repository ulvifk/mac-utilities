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
        state.show()
        #expect(state.results.map(\.name) == ["Safari", "Visual Studio Code", "Xcode"])
        #expect(state.getHighlightedApp() == nil)
    }

    @Test
    func testWhitespaceOnlySearchListsEveryAppWithoutAHighlight() {
        state.show()
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
        state.show()
        state.moveHighlightDown()
        #expect(state.getHighlightedApp()?.name == "Safari")
    }

    @Test
    func testUpWithoutAHighlightHighlightsTheFirstResult() {
        state.show()
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
    func testSettingTheSameSearchTextKeepsTheHighlight() {
        state.changeSearchText(to: "a")
        state.moveHighlightDown()
        state.changeSearchText(to: "a")
        #expect(state.getHighlightedApp()?.name == "Visual Studio Code")
    }

    @Test
    func testChangingOnlyTheSurroundingWhitespaceKeepsTheHighlight() throws {
        state.changeSearchText(to: "a")
        state.moveHighlightDown()
        state.changeSearchText(to: " a ")
        #expect(state.searchText == " a ")
        try #require(state.results.count == 2)
        #expect(state.getHighlightedApp()?.name == "Visual Studio Code")
    }

    @Test
    func testSettingTheSameBlankSearchKeepsTheHighlight() {
        state.show()
        state.moveHighlightDown()
        state.moveHighlightDown()
        state.changeSearchText(to: "")
        #expect(state.getHighlightedApp()?.name == "Visual Studio Code")
    }

    @Test
    func testDeletingTheSearchToBlankClearsTheHighlight() {
        state.changeSearchText(to: "a")
        state.moveHighlightDown()
        state.changeSearchText(to: "")
        #expect(state.highlightedIndex == nil)
    }

    @Test
    func testTypingToASearchWithoutResultsClearsTheHighlight() {
        state.changeSearchText(to: "a")
        state.moveHighlightDown()
        state.changeSearchText(to: "terminal")
        #expect(state.highlightedIndex == nil)
    }

    @Test
    func testHoverHighlightsTheHoveredResult() {
        state.show()
        state.highlightHoveredResult(at: 2, pointerLocation: CGPoint(x: 10, y: 50))
        #expect(state.getHighlightedApp()?.name == "Xcode")
    }

    @Test
    func testHoverWithAStillPointerKeepsTheKeyboardHighlight() {
        state.show()
        state.highlightHoveredResult(at: 0, pointerLocation: CGPoint(x: 10, y: 50))
        state.moveHighlightDown()
        state.moveHighlightDown()
        state.highlightHoveredResult(at: 1, pointerLocation: CGPoint(x: 10, y: 50))
        #expect(state.highlightedIndex == 2)
    }

    @Test
    func testHoverAfterThePointerMovedHighlightsTheHoveredResult() {
        state.show()
        state.highlightHoveredResult(at: 0, pointerLocation: CGPoint(x: 10, y: 50))
        state.moveHighlightDown()
        state.moveHighlightDown()
        state.highlightHoveredResult(at: 1, pointerLocation: CGPoint(x: 10, y: 30))
        #expect(state.highlightedIndex == 1)
    }

    @Test
    func testShowingClearsTheSearchAndTheHighlight() {
        state.changeSearchText(to: "code")
        state.show()
        #expect(state.isShown)
        #expect(state.searchText == "")
        #expect(state.getHighlightedApp() == nil)
    }

    @Test
    func testShowingAfterBrowsingABlankSearchClearsTheHighlight() {
        state.show()
        state.moveHighlightDown()
        state.show()
        #expect(state.getHighlightedApp() == nil)
    }
}
