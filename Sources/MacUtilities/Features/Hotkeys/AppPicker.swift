import SwiftUI

/// The search results scroll beyond this height, so a long list of installed apps stays on screen.
private let searchResultsMaxHeight: CGFloat = 320
private let searchPopoverWidth: CGFloat = 260

/// A button showing the selected app with its icon; it opens a popover with a search field over the installed apps, and choosing one passes its
/// bundle identifier on. It shrinks below the selected app's name, truncating it, so it fits on a binding's row. The button reads "Choose App"
/// while the identifier is not among the installed apps.
struct AppPicker: View {
    let apps: [InstalledApp]
    let selectedBundleIdentifier: String
    let onSelect: (String) -> Void
    @StateObject private var state = AppPickerState()

    var body: some View {
        Button { showSearch() } label: {
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

    private func showSearch() {
        state.searchText = ""
        state.isShown = true
    }

    private func select(_ app: InstalledApp) {
        onSelect(app.bundleIdentifier)
        state.isShown = false
    }

    @ViewBuilder private func buildSelectedAppLabel() -> some View {
        if let selectedApp = apps.first(where: { $0.bundleIdentifier == selectedBundleIdentifier }) {
            buildAppLabel(selectedApp)
        } else {
            Text("Choose App")
                .foregroundStyle(.secondary)
        }
    }

    /// Return chooses the first result.
    private func buildSearch() -> some View {
        let results = getApps(in: apps, withNameContaining: state.searchText)

        return VStack(spacing: 0) {
            TextField("Search Apps", text: $state.searchText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    if let firstResult = results.first { select(firstResult) }
                }
                .padding(10)
            Divider()
            buildResults(results)
        }
        .frame(width: searchPopoverWidth)
    }

    @ViewBuilder private func buildResults(_ results: [InstalledApp]) -> some View {
        if results.isEmpty {
            Text("No Apps Found")
                .foregroundStyle(.secondary)
                .padding(12)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(results, id: \.bundleIdentifier) { app in buildResult(app) }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: searchResultsMaxHeight)
        }
    }

    private func buildResult(_ app: InstalledApp) -> some View {
        return Button { select(app) } label: {
            buildAppLabel(app)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
