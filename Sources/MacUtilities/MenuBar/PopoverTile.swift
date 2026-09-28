import SwiftUI

/// A rounded platter holding one control of the menu bar popover, as Control Center groups its modules.
struct PopoverTile<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(tilePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous).fill(tileFill))
    }
}
