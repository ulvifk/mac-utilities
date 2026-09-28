import Combine

/// The Batch Quit picker's popover: whether it is shown, and which apps were listed when it opened, so its rows keep their place while it is
/// open. A class held as a state object, since the command-line toolchain has no plugin for the @State macro.
final class BatchQuitPickerState: ObservableObject {
    @Published var isShown = false
    var listedWhenShown: Set<String> = []
}
