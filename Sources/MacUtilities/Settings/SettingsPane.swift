import SwiftUI

let generalPaneIdentifier = "general"

/// One entry of the settings window: its row in the sidebar and the pane the row shows.
struct SettingsPane {
    let identifier: String
    let title: String
    let symbolName: String
    let gradient: Gradient
    let view: AnyView
}
