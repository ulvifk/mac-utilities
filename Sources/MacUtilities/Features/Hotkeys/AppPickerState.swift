import Foundation
import Combine

/// An app picker's popover: whether it is shown, the search typed into it, the apps listed for that search, and the one result Return picks.
/// A class held as a state object, since the command-line toolchain has no plugin for the @State macro.
///
/// - Each change of the search text highlights the first result, since the old position now points at a different app; a blank search, or
///   one without results, highlights nothing. Text that differs only in its surrounding whitespace lists the same results, so it keeps the
///   highlight; the search field writes its unchanged text back when Return commits it, just before Return picks the highlighted app.
/// - Up and Down move the highlight one result and stop at either end; from no highlight, either one highlights the first result.
/// - Hovering a row highlights it and the highlight stays there when the pointer leaves, so the pointer and the keys share one highlight.
/// - Keyboard input (a search text change, Up, Down) puts the highlight in the keyboard's hands until the pointer really moves. Each one
///   records where the pointer rests; a hover report at that location is ignored, because when the keys scroll the list or change the
///   results, the row that slides under the still pointer is reported as hovered. A report anywhere else is a real move: it highlights its
///   row and the pointer leads, through wheel scrolling too, until the next keyboard input. The pointer moving within the row it rests on is
///   not reported, so the keyboard highlight stays until the pointer enters another row.
/// The apps are fixed for the picker's life, so the highlighted index always points into the results.
final class AppPickerState: ObservableObject {
    let apps: [InstalledApp] // by name

    @Published var isShown = false
    @Published private(set) var searchText = ""
    @Published private(set) var highlightedIndex: Int? // into results
    private var pointerLocationAtKeyPress: CGPoint? // in screen coordinates, which scrolling does not change; nil while the pointer leads

    init(apps: [InstalledApp]) {
        self.apps = apps
    }

    /// The apps whose name contains the search text without its surrounding whitespace, ignoring case, in their given order; all of them while
    /// the search text is blank.
    /// e.g. " code " over [Safari, Visual Studio Code, Xcode] -> [Visual Studio Code, Xcode]
    var results: [InstalledApp] {
        let trimmedSearchText = getTrimmed(searchText)
        if trimmedSearchText.isEmpty { return apps }

        return apps.filter { $0.name.localizedCaseInsensitiveContains(trimmedSearchText) }
    }

    /// Opens the popover on an empty search with nothing highlighted, the pointer leading.
    func show() {
        searchText = ""
        highlightedIndex = nil
        pointerLocationAtKeyPress = nil
        isShown = true
    }

    /// The pointer location, here and for Up and Down, is the pointer's screen location while the key is pressed.
    func changeSearchText(to newSearchText: String, pointerLocation: CGPoint) {
        pointerLocationAtKeyPress = pointerLocation
        let isSameSearch = getTrimmed(newSearchText) == getTrimmed(searchText)
        searchText = newSearchText
        if isSameSearch { return }

        highlightedIndex = nil
        if getTrimmed(searchText).isEmpty { return }

        highlightFirstResult()
    }

    /// Highlights the hovered result and lets the pointer lead, unless the pointer is where it was at the last key press, which means the list
    /// moved under a still pointer.
    func highlightHoveredResult(at index: Int, pointerLocation: CGPoint) {
        if pointerLocation == pointerLocationAtKeyPress { return }

        pointerLocationAtKeyPress = nil
        highlightedIndex = index
    }

    func moveHighlightUp(pointerLocation: CGPoint) {
        pointerLocationAtKeyPress = pointerLocation
        guard let highlightedIndex else { return highlightFirstResult() }

        self.highlightedIndex = max(highlightedIndex - 1, 0)
    }

    func moveHighlightDown(pointerLocation: CGPoint) {
        pointerLocationAtKeyPress = pointerLocation
        guard let highlightedIndex else { return highlightFirstResult() }

        self.highlightedIndex = min(highlightedIndex + 1, results.count - 1)
    }

    /// What Return picks; nil while nothing is highlighted, which includes a search without results.
    func getHighlightedApp() -> InstalledApp? {
        guard let highlightedIndex else { return nil }

        return results[highlightedIndex]
    }

    private func highlightFirstResult() {
        if results.isEmpty { return }

        highlightedIndex = 0
    }

    private func getTrimmed(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
