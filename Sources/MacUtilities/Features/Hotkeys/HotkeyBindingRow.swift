import SwiftUI

/// One binding: the recorder, the action, its target and the conflict warning when its key is taken.
struct HotkeyBindingRow: View {
    let binding: HotkeyBinding
    let conflictWarning: String?
    let installedApps: [InstalledApp]
    let onChange: (HotkeyBinding) -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                KeyRecorderField(combo: binding.key) { onChange(withKey($0)) }
                    .frame(width: 150)
                Picker("Action", selection: buildTypeBinding()) {
                    ForEach(HotkeyActionType.allCases, id: \.self) { type in
                        Text(type.title)
                    }
                }
                .labelsHidden()
                Spacer()
                Button(action: onRemove) { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless)
            }

            if binding.action.type.takesApp {
                AppPicker(apps: installedApps, selectedBundleIdentifier: binding.action.target) { onChange(withTarget($0)) }
            }
            if binding.action.type == .runCommand {
                TextField("Command for /bin/sh -c", text: buildTargetBinding())
                    .font(.system(.body, design: .monospaced))
            }

            if let conflictWarning {
                Label(conflictWarning, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private func buildTypeBinding() -> Binding<HotkeyActionType> {
        return Binding(
            get: { binding.action.type },
            set: { onChange(withAction(HotkeyAction(type: $0, target: ""))) }
        )
    }

    private func buildTargetBinding() -> Binding<String> {
        return Binding(
            get: { binding.action.target },
            set: { onChange(withTarget($0)) }
        )
    }

    private func withKey(_ key: KeyCombo) -> HotkeyBinding {
        var updated = binding
        updated.key = key
        return updated
    }

    private func withAction(_ action: HotkeyAction) -> HotkeyBinding {
        var updated = binding
        updated.action = action
        return updated
    }

    private func withTarget(_ target: String) -> HotkeyBinding {
        var updated = binding
        updated.action.target = target
        return updated
    }
}
