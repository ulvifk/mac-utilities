import AppKit

final class AppPickerCoordinator: NSObject {
    var onSelect: (String) -> Void = { _ in }

    @objc func handleSelection(_ popUp: NSPopUpButton) {
        onSelect(popUp.selectedItem!.representedObject as! String)
    }
}
