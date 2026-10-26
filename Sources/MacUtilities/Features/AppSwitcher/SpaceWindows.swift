import AppKit

private typealias GetMainConnectionID = @convention(c) () -> Int32
private typealias CopyManagedDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>
private typealias CopyWindowsWithOptionsAndTags = @convention(c) (Int32, UInt32, CFArray, UInt32, UnsafeMutablePointer<UInt64>, UnsafeMutablePointer<UInt64>) -> Unmanaged<CFArray>

private let onlyOrderedInWindows: UInt32 = 0 // the invisible-window flags would add closed windows still kept ordered out
private let normalWindowLayer = 0 // no palettes, panels or menu bar strips

/// The processes with an open window on any Space, other displays' and full-screen ones included, so the switcher lists the same apps on
/// every Space. The accessibility API only sees the current Space, and the public window list cannot tell a window on another Space from a
/// closed one kept ordered out; the window server's listing per Space leaves those out. Minimized windows and hidden apps' windows are ordered
/// out as well, so they are not counted here. CGS* is not in the SDK but still in the dylib.
func getProcessesWithOpenWindowsOnAnySpace() -> Set<pid_t> {
    let handle = dlopen(nil, RTLD_NOW)
    let getMainConnection = unsafeBitCast(dlsym(handle, "CGSMainConnectionID")!, to: GetMainConnectionID.self)
    let copyManagedDisplaySpaces = unsafeBitCast(dlsym(handle, "CGSCopyManagedDisplaySpaces")!, to: CopyManagedDisplaySpaces.self)
    let copyWindows = unsafeBitCast(dlsym(handle, "CGSCopyWindowsWithOptionsAndTags")!, to: CopyWindowsWithOptionsAndTags.self)
    let connection = getMainConnection()

    let displays = copyManagedDisplaySpaces(connection).takeRetainedValue() as! [[String: Any]]
    var setTags: UInt64 = 0
    var clearTags: UInt64 = 0
    let windows = copyWindows(connection, 0, getSpaceIDs(displays) as CFArray, onlyOrderedInWindows, &setTags, &clearTags).takeRetainedValue()
    let windowIDs = Set(windows as! [CGWindowID])

    var processes = Set<pid_t>()
    for window in CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as! [[String: Any]] {
        if !windowIDs.contains(window[kCGWindowNumber as String] as! CGWindowID) { continue }
        if window[kCGWindowLayer as String] as! Int != normalWindowLayer { continue }
        processes.insert(window[kCGWindowOwnerPID as String] as! pid_t)
    }

    return processes
}

/// Every Space of every display, desktops, full-screen apps and Split Views alike.
private func getSpaceIDs(_ displays: [[String: Any]]) -> [Int] {
    var spaceIDs: [Int] = []
    for display in displays {
        for space in display["Spaces"] as! [[String: Any]] {
            spaceIDs.append(space["id64"] as! Int)
        }
    }

    return spaceIDs
}
