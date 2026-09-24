import AppKit
import SwiftUI

/// Pop-up of the installed apps with their icons; the selection is the bundle identifier. Nothing is selected while the identifier is not among the installed apps.
struct AppPicker: NSViewRepresentable {
    let apps: [InstalledApp]
    let selectedBundleIdentifier: String
    let onSelect: (String) -> Void

    func makeCoordinator() -> AppPickerCoordinator {
        return AppPickerCoordinator()
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let popUp = NSPopUpButton(frame: .zero, pullsDown: false)

        for app in apps {
            let item = NSMenuItem(title: app.name, action: nil, keyEquivalent: "")
            item.image = app.icon
            item.representedObject = app.bundleIdentifier
            popUp.menu!.addItem(item)
        }

        popUp.target = context.coordinator
        popUp.action = #selector(AppPickerCoordinator.handleSelection)
        return popUp
    }

    func updateNSView(_ popUp: NSPopUpButton, context: Context) {
        context.coordinator.onSelect = onSelect
        popUp.select(popUp.menu!.items.first { $0.representedObject as! String == selectedBundleIdentifier })
    }
}

final class AppPickerCoordinator: NSObject {
    var onSelect: (String) -> Void = { _ in }

    @objc func handleSelection(_ popUp: NSPopUpButton) {
        onSelect(popUp.selectedItem!.representedObject as! String)
    }
}
