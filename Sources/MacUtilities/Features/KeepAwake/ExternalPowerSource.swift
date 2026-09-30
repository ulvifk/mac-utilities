import Combine
import IOKit.ps

final class ExternalPowerSource: ObservableObject {
    @Published private(set) var isConnected: Bool

    private var notificationSource: CFRunLoopSource!

    init() {
        isConnected = Self.isConnectedToPower()

        notificationSource = IOPSNotificationCreateRunLoopSource({ context in
            let powerSource = Unmanaged<ExternalPowerSource>.fromOpaque(context!).takeUnretainedValue()
            powerSource.isConnected = ExternalPowerSource.isConnectedToPower()
        }, Unmanaged.passUnretained(self).toOpaque()).takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), notificationSource, .commonModes)
    }

    deinit {
        CFRunLoopSourceInvalidate(notificationSource)
    }

    private static func isConnectedToPower() -> Bool {
        let information = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sourceType = IOPSGetProvidingPowerSourceType(information).takeUnretainedValue() as String
        return sourceType == kIOPSACPowerValue
    }
}
