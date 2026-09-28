import SwiftUI

/// Room for either app action, so the app pickers line up in a column; the other actions, which have no app picker, take their own width.
private let actionPickerMinWidth: CGFloat = 140
private let appPickerWidthRange: ClosedRange<CGFloat> = 110...190
private let keyRecorderSize = CGSize(width: 124, height: 22)

/// One binding: the action, the app it acts on, the recorder showing the combo as keycaps and a remove button on one line; a command gets
/// the full width of the line below, and the conflict warning comes last when the key is taken.
struct HotkeyBindingRow: View {
    let binding: HotkeyBinding
    let conflictWarning: String?
    let installedApps: [InstalledApp]
    let onChange: (HotkeyBinding) -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Picker("Action", selection: buildTypeBinding()) {
                    ForEach(HotkeyActionType.allCases, id: \.self) { type in
                        Label(type.title, systemImage: type.symbolName)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .frame(minWidth: actionPickerMinWidth, alignment: .leading)

                if binding.action.type.takesApp {
                    AppPicker(apps: installedApps, selectedBundleIdentifier: binding.action.target) { onChange(withTarget($0)) }
                        .frame(minWidth: appPickerWidthRange.lowerBound, maxWidth: appPickerWidthRange.upperBound)
                }

                Spacer(minLength: 8)

                KeyRecorderField(combo: binding.key) { onChange(withKey($0)) }
                    .frame(width: keyRecorderSize.width, height: keyRecorderSize.height)
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Remove this hotkey")
            }

            if binding.action.type == .runCommand {
                TextField("Command for /bin/sh -c", text: buildTargetBinding())
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .labelsHidden()
            }

            if let conflictWarning {
                Label(conflictWarning, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
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
