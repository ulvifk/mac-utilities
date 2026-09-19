import AppKit

func runApplication() throws {
    let lockPath = NSHomeDirectory() + "/Library/Caches/com.ulvifk.my-dock.lock"
    let lockDescriptor = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    if lockDescriptor == -1 {
        perror("MyDock lock")
        exit(EXIT_FAILURE)
    }
    defer { close(lockDescriptor) }
    if flock(lockDescriptor, LOCK_EX | LOCK_NB) != 0 {
        if errno == EWOULDBLOCK {
            print("MyDock is already running.")
            return
        }
        perror("MyDock lock")
        exit(EXIT_FAILURE)
    }

    let fileURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/MyDock/apps.json")
    let store = DockStateStore(fileURL: fileURL)
    let state = try store.load() ?? DockState(visibleApps: AppCatalog.importDockPins(), hiddenApps: [], isCollapsed: true)
    try store.save(state)
    let application = NSApplication.shared
    let session = DockSession(store: store, state: state)
    let controller = MyDockController(session: session)
    application.setActivationPolicy(.accessory)
    application.delegate = controller
    withExtendedLifetime(controller) { application.run() }
}

try runApplication()
