import Combine

/// An app picker's popover: whether it is shown, and the search typed into it.
/// A class held as a state object, since the command-line toolchain has no plugin for the @State macro.
final class AppPickerState: ObservableObject {
    @Published var isShown = false
    @Published var searchText = ""
}
