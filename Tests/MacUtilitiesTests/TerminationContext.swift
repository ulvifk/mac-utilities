/// Where Quit starts. dispatch and task quit as the app's Quit buttons do, from a main-queue job and from a Task; native is AppKit's own
/// request, made outside any main-queue job, as a Quit from the Dock or a logout is.
enum TerminationContext: String, CaseIterable, Codable, Sendable {
    case dispatch
    case task
    case native
}
