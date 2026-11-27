import Foundation
import Combine

/// An app picker's popover: whether it is shown, the search typed into it, the apps listed for that search, and the one result Return picks.
/// A class held as a state object, since the command-line toolchain has no plugin for the @State macro.
///
/// - Each change of the search text highlights the first result, since the old position now points at a different app; a blank search, or
///   one without results, highlights nothing.
/// - Up and Down move the highlight one result and stop at either end; from no highlight, either one highlights the first result.
/// - Hovering a row highlights it and the highlight stays there when the pointer leaves, so the pointer and the keys share one highlight.
/// The apps are fixed for the picker's life, so the highlighted index always points into the results.
final class AppPickerState: ObservableObject {
    let apps: [InstalledApp] // by name

    @Published var isShown = false
    @Published private(set) var searchText = ""
    @Published private(set) var highlightedIndex: Int? // into results

    init(apps: [InstalledApp]) {
        self.apps = apps
    }

    /// The apps whose name contains the search text without its surrounding whitespace, ignoring case, in their given order; all of them while
    /// the search text is blank.
    /// e.g. " code " over [Safari, Visual Studio Code, Xcode] -> [Visual Studio Code, Xcode]
    var results: [InstalledApp] {
        let trimmedSearchText = getTrimmedSearchText()
        if trimmedSearchText.isEmpty { return apps }

        return apps.filter { $0.name.localizedCaseInsensitiveContains(trimmedSearchText) }
    }

    /// Opens the popover on an empty search.
    func show() {
        changeSearchText(to: "")
        isShown = true
    }

    func changeSearchText(to newSearchText: String) {
        searchText = newSearchText
        highlightedIndex = nil
        if getTrimmedSearchText().isEmpty { return }

        highlightFirstResult()
    }

    func highlightResult(at index: Int) {
        highlightedIndex = index
    }

    func moveHighlightUp() {
        guard let highlightedIndex else { return highlightFirstResult() }

        self.highlightedIndex = max(highlightedIndex - 1, 0)
    }

    func moveHighlightDown() {
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

    private func getTrimmedSearchText() -> String {
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
