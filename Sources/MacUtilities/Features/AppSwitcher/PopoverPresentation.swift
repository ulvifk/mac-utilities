import Combine

/// Whether a view's popover is shown. A class held as a state object, since the command-line toolchain has no plugin for the @State macro.
final class PopoverPresentation: ObservableObject {
    @Published var isShown = false
}
