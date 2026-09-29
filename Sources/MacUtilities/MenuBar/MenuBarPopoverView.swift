import SwiftUI

private let pauseTint = Color.indigo
private let activeStatusColor = Color.green
private let shortcutsOffStatusColor = Color.orange
private let statusDotSize: CGFloat = 8

/// The popover under the menu bar item: a header saying whether the shortcuts are live, the Pause tile, the enabled features' tiles, then
/// Settings and Quit.
struct MenuBarPopoverView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        VStack(alignment: .leading, spacing: popoverSectionSpacing) {
            buildHeader()

            VStack(spacing: tileSpacing) {
                buildPauseTile()
                ForEach(controller.enabledFeatures, id: \.identifier) { feature in
                    feature.buildPopoverTile()
                }
            }

            buildFooter()
        }
        .padding(popoverPadding)
        .frame(width: popoverWidth)
    }

    /// The app icon's body lines up with the round toggles below it, and the title with theirs.
    private func buildHeader() -> some View {
        return HStack(spacing: roundToggleSpacing - popoverAppIconMargin) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: popoverAppIconSize, height: popoverAppIconSize)
            VStack(alignment: .leading, spacing: 2) {
                Text("MacUtilities")
                    .font(popoverTitleFont)
                HStack(spacing: 5) {
                    Circle()
                        .fill(getStatusColor())
                        .frame(width: statusDotSize, height: statusDotSize)
                    Text(getStatusText())
                        .font(secondaryLineFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, tilePadding - popoverAppIconMargin)
    }

    private func buildPauseTile() -> some View {
        return PopoverTile {
            PopoverToggleRow(
                title: "Pause Shortcuts",
                subtitle: Text(controller.isPaused ? "On" : "Off"),
                symbolName: "pause.fill",
                tint: pauseTint,
                isOn: controller.isPaused,
                toggle: controller.togglePause
            )
        }
    }

    private func buildFooter() -> some View {
        return HStack {
            Button { controller.openSettings() } label: {
                Label("Settings…", systemImage: "gearshape")
            }
            .keyboardShortcut(",")

            Spacer()

            Button { terminateApplication() } label: {
                Label("Quit", systemImage: "power")
            }
            .keyboardShortcut("q")
        }
        .controlSize(.small)
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
    }

    /// No shortcut works without the event tap, paused or not.
    private func getStatusText() -> String {
        if !controller.isEventTapRunning { return "Shortcuts off — see Settings" }
        if controller.isPaused { return "Paused — keys pass through untouched" }
        return "All shortcuts active"
    }

    private func getStatusColor() -> Color {
        if !controller.isEventTapRunning { return shortcutsOffStatusColor }
        if controller.isPaused { return pauseTint }
        return activeStatusColor
    }
}
