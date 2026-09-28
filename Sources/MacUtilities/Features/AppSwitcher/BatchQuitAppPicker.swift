import SwiftUI

/// The checklist scrolls beyond this height, so a long list of running apps stays on screen.
private let checklistMaxHeight: CGFloat = 440

/// A button counting the running apps on the Batch Quit list. It opens a popover with a checkbox for each app that can go on it, the listed ones
/// above a divider; unlike a menu, the popover stays open while several are checked.
struct BatchQuitAppPicker: View {
    @ObservedObject var batchQuitStore: BatchQuitStore
    /// By name.
    let apps: [NSRunningApplication]
    @StateObject private var presentation = PopoverPresentation()

    var body: some View {
        Button { presentation.isShown = true } label: {
            HStack(spacing: 4) {
                Text(getSummary())
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .imageScale(.small)
            }
        }
        .popover(isPresented: $presentation.isShown, arrowEdge: .bottom) {
            buildChecklist()
        }
    }

    /// A count rather than names, which would stretch the button across the tab.
    private func getSummary() -> String {
        let listedCount = getApps(listed: true).count
        if listedCount == 0 { return "None" }
        if listedCount == 1 { return "1 app" }

        return "\(listedCount) apps"
    }

    private func getApps(listed: Bool) -> [NSRunningApplication] {
        return apps.filter { batchQuitStore.isListed($0.bundleIdentifier!) == listed }
    }

    private func buildChecklist() -> some View {
        let listedApps = getApps(listed: true)

        return ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(listedApps, id: \.processIdentifier) { app in buildCheckbox(app) }
                if !listedApps.isEmpty {
                    Divider()
                }
                ForEach(getApps(listed: false), id: \.processIdentifier) { app in buildCheckbox(app) }
            }
            .padding(12)
        }
        .frame(maxHeight: checklistMaxHeight)
    }

    private func buildCheckbox(_ app: NSRunningApplication) -> some View {
        return Toggle(isOn: buildListedBinding(bundleIdentifier: app.bundleIdentifier!)) {
            HStack(spacing: 6) {
                Image(nsImage: app.icon!)
                    .resizable()
                    .frame(width: 16, height: 16)
                Text(getAppName(app))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .toggleStyle(.checkbox)
    }

    private func buildListedBinding(bundleIdentifier: String) -> Binding<Bool> {
        return Binding(
            get: { batchQuitStore.isListed(bundleIdentifier) },
            set: { batchQuitStore.setListed(bundleIdentifier, $0) }
        )
    }
}
