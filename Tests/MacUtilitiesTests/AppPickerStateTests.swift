import AppKit
import Testing
@testable import MacUtilities

struct AppPickerStateTests {
    private let restingPointer = CGPoint(x: 10, y: 50)
    private let state = AppPickerState(apps: ["Safari", "Visual Studio Code", "Xcode"].map {
        InstalledApp(bundleIdentifier: "test.\($0)", name: $0, icon: NSImage())
    })

    @Test
    func testSearchMatchesAnywhereInTheNameIgnoringCase() {
        state.changeSearchText(to: "CODE", pointerLocation: restingPointer)
        #expect(state.results.map(\.name) == ["Visual Studio Code", "Xcode"])
    }

    @Test
    func testSearchIgnoresSurroundingWhitespace() {
        state.changeSearchText(to: " code ", pointerLocation: restingPointer)
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
        state.changeSearchText(to: "  ", pointerLocation: restingPointer)
        #expect(state.results.map(\.name) == ["Safari", "Visual Studio Code", "Xcode"])
        #expect(state.getHighlightedApp() == nil)
    }

    @Test
    func testSearchHighlightsTheFirstResult() {
        state.changeSearchText(to: "code", pointerLocation: restingPointer)
        #expect(state.getHighlightedApp()?.name == "Visual Studio Code")
    }

    @Test
    func testSearchWithoutResultsHighlightsNothing() {
        state.changeSearchText(to: "terminal", pointerLocation: restingPointer)
        #expect(state.results.isEmpty)
        #expect(state.highlightedIndex == nil)
    }

    @Test
    func testDownStopsAtTheLastResult() throws {
        state.changeSearchText(to: "a", pointerLocation: restingPointer)
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.moveHighlightDown(pointerLocation: restingPointer)
        try #require(state.highlightedIndex == 1)
        #expect(state.getHighlightedApp()?.name == "Visual Studio Code")
    }

    @Test
    func testUpStopsAtTheFirstResult() throws {
        state.changeSearchText(to: "a", pointerLocation: restingPointer)
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.moveHighlightUp(pointerLocation: restingPointer)
        state.moveHighlightUp(pointerLocation: restingPointer)
        try #require(state.highlightedIndex == 0)
        #expect(state.getHighlightedApp()?.name == "Safari")
    }

    @Test
    func testDownWithoutAHighlightHighlightsTheFirstResult() {
        state.show()
        state.moveHighlightDown(pointerLocation: restingPointer)
        #expect(state.getHighlightedApp()?.name == "Safari")
    }

    @Test
    func testUpWithoutAHighlightHighlightsTheFirstResult() {
        state.show()
        state.moveHighlightUp(pointerLocation: restingPointer)
        #expect(state.getHighlightedApp()?.name == "Safari")
    }

    @Test
    func testMovingWithoutResultsHighlightsNothing() {
        state.changeSearchText(to: "terminal", pointerLocation: restingPointer)
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.moveHighlightUp(pointerLocation: restingPointer)
        #expect(state.highlightedIndex == nil)
    }

    @Test
    func testNarrowingTheSearchHighlightsTheFirstOfTheFewerResults() {
        state.changeSearchText(to: "a", pointerLocation: restingPointer)
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.changeSearchText(to: "sa", pointerLocation: restingPointer)
        #expect(state.getHighlightedApp()?.name == "Safari")
    }

    @Test
    func testWideningTheSearchHighlightsTheFirstOfTheMoreResults() {
        state.changeSearchText(to: "code", pointerLocation: restingPointer)
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.changeSearchText(to: "c", pointerLocation: restingPointer)
        #expect(state.results.map(\.name) == ["Visual Studio Code", "Xcode"])
        #expect(state.getHighlightedApp()?.name == "Visual Studio Code")
    }

    @Test
    func testSettingTheSameSearchTextKeepsTheHighlight() {
        state.changeSearchText(to: "a", pointerLocation: restingPointer)
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.changeSearchText(to: "a", pointerLocation: restingPointer)
        #expect(state.getHighlightedApp()?.name == "Visual Studio Code")
    }

    @Test
    func testChangingOnlyTheSurroundingWhitespaceKeepsTheHighlight() throws {
        state.changeSearchText(to: "a", pointerLocation: restingPointer)
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.changeSearchText(to: " a ", pointerLocation: restingPointer)
        #expect(state.searchText == " a ")
        try #require(state.results.count == 2)
        #expect(state.getHighlightedApp()?.name == "Visual Studio Code")
    }

    @Test
    func testSettingTheSameBlankSearchKeepsTheHighlight() {
        state.show()
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.changeSearchText(to: "", pointerLocation: restingPointer)
        #expect(state.getHighlightedApp()?.name == "Visual Studio Code")
    }

    @Test
    func testDeletingTheSearchToBlankClearsTheHighlight() {
        state.changeSearchText(to: "a", pointerLocation: restingPointer)
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.changeSearchText(to: "", pointerLocation: restingPointer)
        #expect(state.highlightedIndex == nil)
    }

    @Test
    func testTypingToASearchWithoutResultsClearsTheHighlight() {
        state.changeSearchText(to: "a", pointerLocation: restingPointer)
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.changeSearchText(to: "terminal", pointerLocation: restingPointer)
        #expect(state.highlightedIndex == nil)
    }

    @Test
    func testHoverHighlightsTheHoveredResult() {
        state.show()
        state.highlightHoveredResult(at: 2, pointerLocation: CGPoint(x: 10, y: 50))
        #expect(state.getHighlightedApp()?.name == "Xcode")
    }

    /// As in the app: the pointer enters row 0 at its edge and comes to rest further in without a report, the keys move the highlight, and the
    /// list scrolls row 1 under the resting pointer.
    @Test
    func testScrollingUnderARestingPointerKeepsTheKeyboardHighlight() {
        state.show()
        state.highlightHoveredResult(at: 0, pointerLocation: CGPoint(x: 10, y: 60))
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.highlightHoveredResult(at: 1, pointerLocation: restingPointer)
        #expect(state.highlightedIndex == 2)
    }

    @Test
    func testScrollingUpUnderARestingPointerKeepsTheKeyboardHighlight() {
        state.show()
        state.highlightHoveredResult(at: 2, pointerLocation: CGPoint(x: 10, y: 60))
        state.moveHighlightUp(pointerLocation: restingPointer)
        state.moveHighlightUp(pointerLocation: restingPointer)
        state.highlightHoveredResult(at: 1, pointerLocation: restingPointer)
        #expect(state.highlightedIndex == 0)
    }

    /// As in the app: the pointer enters row 2 at its edge and comes to rest further in without a report, typing changes the results, and the
    /// row now under the resting pointer is reported as hovered.
    @Test
    func testTypingUnderARestingPointerKeepsTheFirstResultHighlighted() {
        state.show()
        state.highlightHoveredResult(at: 2, pointerLocation: CGPoint(x: 10, y: 60))
        state.changeSearchText(to: "a", pointerLocation: restingPointer)
        state.highlightHoveredResult(at: 1, pointerLocation: restingPointer)
        #expect(state.highlightedIndex == 0)
    }

    @Test
    func testDownFromNoHighlightRecordsTheRestingPointer() {
        state.show()
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.highlightHoveredResult(at: 2, pointerLocation: restingPointer)
        #expect(state.highlightedIndex == 0)
    }

    @Test
    func testUpFromNoHighlightRecordsTheRestingPointer() {
        state.show()
        state.moveHighlightUp(pointerLocation: restingPointer)
        state.highlightHoveredResult(at: 2, pointerLocation: restingPointer)
        #expect(state.highlightedIndex == 0)
    }

    /// As in the app when the wheel scrolls the list under a pointer that moved: every tick reports the row now under it, at one location.
    @Test
    func testAfterThePointerMovedEachHoverReportAtOneLocationHighlightsItsRow() {
        state.show()
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.highlightHoveredResult(at: 1, pointerLocation: CGPoint(x: 10, y: 30))
        state.highlightHoveredResult(at: 2, pointerLocation: CGPoint(x: 10, y: 30))
        #expect(state.highlightedIndex == 2)
    }

    @Test
    func testAfterThePointerMovedItLeadsEvenAtTheKeyPressLocation() {
        state.show()
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.highlightHoveredResult(at: 1, pointerLocation: CGPoint(x: 10, y: 30))
        state.highlightHoveredResult(at: 2, pointerLocation: restingPointer)
        #expect(state.highlightedIndex == 2)
    }

    @Test
    func testReturnWritingBackTheTextKeepsTheHoveredResult() {
        state.changeSearchText(to: "a", pointerLocation: restingPointer)
        state.highlightHoveredResult(at: 1, pointerLocation: CGPoint(x: 10, y: 30))
        state.changeSearchText(to: "a", pointerLocation: CGPoint(x: 10, y: 30))
        #expect(state.getHighlightedApp()?.name == "Visual Studio Code")
    }

    @Test
    func testHoverAfterThePointerMovedSidewaysHighlightsTheHoveredResult() {
        state.show()
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.highlightHoveredResult(at: 2, pointerLocation: CGPoint(x: 40, y: restingPointer.y))
        #expect(state.highlightedIndex == 2)
    }

    @Test
    func testWritingBackUnchangedTextRecordsTheRestingPointer() {
        state.changeSearchText(to: "a", pointerLocation: restingPointer)
        state.highlightHoveredResult(at: 1, pointerLocation: CGPoint(x: 10, y: 30))
        state.changeSearchText(to: "a", pointerLocation: CGPoint(x: 25, y: 70))
        state.highlightHoveredResult(at: 0, pointerLocation: CGPoint(x: 25, y: 70))
        #expect(state.highlightedIndex == 1)
    }

    @Test
    func testShowingLetsThePointerLead() {
        state.changeSearchText(to: "a", pointerLocation: restingPointer)
        state.show()
        state.highlightHoveredResult(at: 2, pointerLocation: restingPointer)
        #expect(state.highlightedIndex == 2)
    }

    @Test
    func testHoverAfterThePointerMovedHighlightsTheHoveredResult() {
        state.show()
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.highlightHoveredResult(at: 2, pointerLocation: CGPoint(x: 10, y: 30))
        #expect(state.highlightedIndex == 2)
    }

    @Test
    func testShowingClearsTheSearchAndTheHighlight() {
        state.changeSearchText(to: "code", pointerLocation: restingPointer)
        state.show()
        #expect(state.isShown)
        #expect(state.searchText == "")
        #expect(state.getHighlightedApp() == nil)
    }

    @Test
    func testShowingAfterBrowsingABlankSearchClearsTheHighlight() {
        state.show()
        state.moveHighlightDown(pointerLocation: restingPointer)
        state.show()
        #expect(state.getHighlightedApp() == nil)
    }
}
