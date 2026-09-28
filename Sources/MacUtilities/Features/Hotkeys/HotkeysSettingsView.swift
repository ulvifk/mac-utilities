import SwiftUI

/// The Hotkeys pane's sections: the bindings, one row each, with add and remove, or an empty state inviting the first one; every change is
/// written to hotkeys.json and live at once. While the file does not parse, its error is shown instead and nothing is written over it. The
/// footer names the file, with a button revealing it in Finder.
struct HotkeysSettingsView: View {
    @ObservedObject var store: HotkeyBindingsStore
    @StateObject private var installedApps = InstalledApps()

    var body: some View {
        Section {
            if let loadError = store.loadError {
                buildLoadErrorRow(loadError)
            } else if store.bindings.isEmpty {
                emptyState
            } else {
                bindingRows
            }
        } footer: {
            footer
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Hotkeys", systemImage: "keyboard")
        } description: {
            Text("Bind a key combo to open an app, run a command or toggle Keep Awake.")
        } actions: {
            Button("Add Hotkey") { store.add(buildNewBinding()) }
        }
    }

    @ViewBuilder private var bindingRows: some View {
        ForEach(store.bindings.indices, id: \.self) { index in
            HotkeyBindingRow(
                binding: store.bindings[index],
                conflictWarning: getConflictWarning(index: index, bindings: store.bindings),
                installedApps: installedApps.apps,
                onChange: { store.replace(at: index, with: $0) },
                onRemove: { store.remove(at: index) }
            )
        }
        Button { store.add(buildNewBinding()) } label: {
            Label("Add Hotkey", systemImage: "plus")
        }
    }

    /// The file is only written on the first change, so until then there is nothing to reveal.
    private var footer: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Saved in \(getAbbreviatedPath()), where edits apply on the spot. A bound key never reaches the focused app.")
            Spacer(minLength: 12)
            if FileManager.default.fileExists(atPath: store.path) {
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: store.path)]) }
                    .controlSize(.small)
            }
        }
    }

    private func buildLoadErrorRow(_ loadError: String) -> some View {
        return VStack(alignment: .leading, spacing: 4) {
            Label("hotkeys.json does not parse", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(loadError)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("The hotkeys in use stay as they were, and nothing is written to the file until it parses again.")
                .foregroundStyle(.secondary)
        }
    }

    private func getAbbreviatedPath() -> String {
        return (store.path as NSString).abbreviatingWithTildeInPath
    }

    private func buildNewBinding() -> HotkeyBinding {
        return HotkeyBinding(key: nil, action: HotkeyAction(type: .activateApp, target: installedApps.apps[0].bundleIdentifier))
    }
}
