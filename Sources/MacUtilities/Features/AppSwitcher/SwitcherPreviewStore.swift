import Combine

final class SwitcherPreviewStore: ObservableObject {
    @Published var isShown = false
    @Published var isListingWindows = false
}
