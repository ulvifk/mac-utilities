import AppKit

private typealias GetMainConnectionID = @convention(c) () -> Int32
private typealias SetConnectionProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

/// The window server ignores cursor changes from an app that is not active, and the panel never activates the app; this private connection property lifts that. CGS* is not in the SDK but still in the dylib.
func enableCursorChangesWhileInactive() {
    let handle = dlopen(nil, RTLD_NOW)
    let getMainConnection = unsafeBitCast(dlsym(handle, "CGSMainConnectionID")!, to: GetMainConnectionID.self)
    let setProperty = unsafeBitCast(dlsym(handle, "CGSSetConnectionProperty")!, to: SetConnectionProperty.self)
    let connection = getMainConnection()

    _ = setProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
}
