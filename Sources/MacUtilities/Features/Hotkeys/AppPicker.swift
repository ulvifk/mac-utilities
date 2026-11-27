import SwiftUI

/// The search results scroll beyond this height, so a long list of installed apps stays on screen.
private let searchResultsMaxHeight: CGFloat = 320
private let searchPopoverWidth: CGFloat = 260
private let highlightedResultBackground = Color.accentColor.opacity(0.25)

/// A button showing the selected app with its icon; it opens a popover with a search field over the installed apps, and choosing one passes its
/// bundle identifier on. It shrinks below the selected app's name, truncating it, so it fits on a binding's row. The button reads "Choose App"
/// while the identifier is not among the installed apps.
struct AppPicker: View {
    let selectedBundleIdentifier: String
    let onSelect: (String) -> Void
    @StateObject private var state: AppPickerState
    @FocusState private var isSearchFieldFocused: Bool

    /// The apps are read once, when the picker first appears; the settings pane scans them once for its whole life.
    init(apps: [InstalledApp], selectedBundleIdentifier: String, onSelect: @escaping (String) -> Void) {
        self.selectedBundleIdentifier = selectedBundleIdentifier
        self.onSelect = onSelect
        _state = StateObject(wrappedValue: AppPickerState(apps: apps))
    }

    var body: some View {
        Button { state.show() } label: {
            HStack(spacing: 6) {
                buildSelectedAppLabel()
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
            }
        }
        .popover(isPresented: $state.isShown, arrowEdge: .bottom) {
            buildSearch()
        }
    }

    private func select(_ app: InstalledApp) {
        onSelect(app.bundleIdentifier)
        state.isShown = false
    }

    private func selectHighlightedApp() {
        guard let highlightedApp = state.getHighlightedApp() else { return }

        select(highlightedApp)
    }

    @ViewBuilder private func buildSelectedAppLabel() -> some View {
        if let selectedApp = state.apps.first(where: { $0.bundleIdentifier == selectedBundleIdentifier }) {
            buildAppLabel(selectedApp)
        } else {
            Text("Choose App")
                .foregroundStyle(.secondary)
        }
    }

    /// The popover's content: a search field, focused when it opens, over the apps whose name matches it, one of them highlighted; Up and Down
    /// move the highlight, scrolling it into view, and Return chooses the highlighted app.
    private func buildSearch() -> some View {
        return VStack(spacing: 0) {
            TextField("Search Apps", text: Binding(get: { state.searchText }, set: state.changeSearchText))
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFieldFocused)
                .onKeyPress(.upArrow) {
                    state.moveHighlightUp()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    state.moveHighlightDown()
                    return .handled
                }
                .onSubmit { selectHighlightedApp() }
                .padding(10)
            Divider()
            buildResults()
        }
        .frame(width: searchPopoverWidth)
        .onAppear { isSearchFieldFocused = true }
    }

    @ViewBuilder private func buildResults() -> some View {
        let results = state.results

        if results.isEmpty {
            Text("No Apps Found")
                .foregroundStyle(.secondary)
                .padding(12)
        } else {
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(results.enumerated()), id: \.element.bundleIdentifier) { index, app in buildResult(app, at: index) }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: searchResultsMaxHeight)
                .onChange(of: state.getHighlightedApp()?.bundleIdentifier) { _, highlightedBundleIdentifier in
                    guard let highlightedBundleIdentifier else { return }

                    scrollView.scrollTo(highlightedBundleIdentifier)
                }
            }
        }
    }

    private func buildResult(_ app: InstalledApp, at index: Int) -> some View {
        return Button { select(app) } label: {
            buildAppLabel(app)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(state.highlightedIndex == index ? highlightedResultBackground : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            if isHovered { state.highlightResult(at: index) }
        }
    }

    private func buildAppLabel(_ app: InstalledApp) -> some View {
        return HStack(spacing: 6) {
            Image(nsImage: app.icon)
            Text(app.name)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
