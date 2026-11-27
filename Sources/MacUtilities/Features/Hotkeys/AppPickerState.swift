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
///   A hover report counts only when the pointer has moved since the keys last moved the highlight or since the previous hover report,
///   whichever came later: as the keys scroll the list, the row sliding under a still pointer is reported as hovered, and must not take the
///   highlight back from the keys. The pointer moving within the row it rests on is not reported, so the keyboard highlight stays until the
///   pointer enters another row.
/// The apps are fixed for the picker's life, so the highlighted index always points into the results.
final class AppPickerState: ObservableObject {
    let apps: [InstalledApp] // by name

    @Published var isShown = false
    @Published private(set) var searchText = ""
    @Published private(set) var highlightedIndex: Int? // into results
    private var lastKnownPointerLocation: CGPoint? // at the last key move or hover report; in screen coordinates, which scrolling does not change

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

    /// Opens the popover on an empty search with nothing highlighted.
    func show() {
        searchText = ""
        highlightedIndex = nil
        isShown = true
    }

    func changeSearchText(to newSearchText: String) {
        let isSameSearch = getTrimmed(newSearchText) == getTrimmed(searchText)
        searchText = newSearchText
        if isSameSearch { return }

        highlightedIndex = nil
        if getTrimmed(searchText).isEmpty { return }

        highlightFirstResult()
    }

    /// Highlights the hovered result, unless the pointer is where it was at the last key move or hover report, which means the list scrolled
    /// under a still pointer.
    func highlightHoveredResult(at index: Int, pointerLocation: CGPoint) {
        if pointerLocation == lastKnownPointerLocation { return }

        lastKnownPointerLocation = pointerLocation
        highlightedIndex = index
    }

    /// The pointer location, in screen coordinates, is where the pointer rests while the key is pressed; see highlightHoveredResult.
    func moveHighlightUp(pointerLocation: CGPoint) {
        lastKnownPointerLocation = pointerLocation
        guard let highlightedIndex else { return highlightFirstResult() }

        self.highlightedIndex = max(highlightedIndex - 1, 0)
    }

    func moveHighlightDown(pointerLocation: CGPoint) {
        lastKnownPointerLocation = pointerLocation
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
