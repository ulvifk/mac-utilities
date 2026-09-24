import SwiftUI

/// The bindings, one row each, with add and remove; every change is written to hotkeys.json and live at once. While the file does not parse, its error is shown instead and nothing is written over it.
struct HotkeysSettingsView: View {
    @ObservedObject var store: HotkeyBindingsStore
    @StateObject private var installedApps = InstalledApps()

    var body: some View {
        Form {
            Section {
                if let loadError = store.loadError {
                    Label(loadError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else {
                    bindingRows
                }
            } footer: {
                Text("Stored in \(store.path); edits made there apply on the spot. A bound key never reaches the focused app.")
            }
        }
        .formStyle(.grouped)
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
        Button("Add binding") { store.add(buildNewBinding()) }
    }

    private func buildNewBinding() -> HotkeyBinding {
        return HotkeyBinding(key: nil, action: HotkeyAction(type: .activateApp, target: installedApps.apps[0].bundleIdentifier))
    }
}
