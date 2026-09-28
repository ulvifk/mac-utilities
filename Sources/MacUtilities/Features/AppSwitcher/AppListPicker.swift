import SwiftUI

/// The checklist scrolls beyond this height, so a long list of running apps stays on screen.
private let checklistMaxHeight: CGFloat = 440

/// A button counting the running apps on a saved app list. It opens a popover with a checkbox for each app that can go on it, the ones listed at
/// that moment above a divider; unlike a menu, the popover stays open while several are checked, and its rows stay in place meanwhile.
struct AppListPicker<Store: AppListStore>: View {
    @ObservedObject var store: Store
    /// By name.
    let apps: [NSRunningApplication]
    @StateObject private var state = AppListPickerState()

    var body: some View {
        Button { showChecklist() } label: {
            HStack(spacing: 4) {
                Text(getSummary())
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .imageScale(.small)
            }
        }
        .popover(isPresented: $state.isShown, arrowEdge: .bottom) {
            buildChecklist()
        }
    }

    private func showChecklist() {
        state.listedWhenShown = Set(apps.map { $0.bundleIdentifier! }.filter(store.isListed))
        state.isShown = true
    }

    /// A count rather than names, which would stretch the button across the tab.
    private func getSummary() -> String {
        let listedCount = apps.filter { store.isListed($0.bundleIdentifier!) }.count
        if listedCount == 0 { return "None" }
        if listedCount == 1 { return "1 app" }

        return "\(listedCount) apps"
    }

    /// Grouped by the list as it was when the popover opened, so checking an app does not move the rows under the pointer.
    private func getChecklistGroup(listedWhenShown: Bool) -> [NSRunningApplication] {
        return apps.filter { state.listedWhenShown.contains($0.bundleIdentifier!) == listedWhenShown }
    }

    private func buildChecklist() -> some View {
        let listedGroup = getChecklistGroup(listedWhenShown: true)
        let unlistedGroup = getChecklistGroup(listedWhenShown: false)

        return ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(listedGroup, id: \.processIdentifier) { app in buildCheckbox(app) }
                if isDividerNeeded(between: listedGroup, and: unlistedGroup) {
                    Divider()
                }
                ForEach(unlistedGroup, id: \.processIdentifier) { app in buildCheckbox(app) }
            }
            .padding(12)
        }
        .frame(maxHeight: checklistMaxHeight)
    }

    /// Only between two groups that both have apps.
    private func isDividerNeeded(between listedGroup: [NSRunningApplication], and unlistedGroup: [NSRunningApplication]) -> Bool {
        if listedGroup.isEmpty { return false }
        return !unlistedGroup.isEmpty
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
            get: { store.isListed(bundleIdentifier) },
            set: { store.setListed(bundleIdentifier, $0) }
        )
    }
}
