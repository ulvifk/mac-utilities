import CoreAudio
import Foundation

final class SystemAudioInput: AudioInput {
    private static let observedProperties = [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultInputDevice]

    private var listener: AudioObjectPropertyListenerBlock?

    deinit {
        stopObserving()
    }

    func getInputDevices() -> [AudioInputDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        precondition(sizeStatus == noErr, "Couldn't read audio device list size: \(sizeStatus)")

        var deviceIDs = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        let devicesStatus = deviceIDs.withUnsafeMutableBytes { buffer in
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, buffer.baseAddress!)
        }
        precondition(devicesStatus == noErr, "Couldn't read audio devices: \(devicesStatus)")

        return deviceIDs.compactMap { getInputDevice($0) }
    }

    func getDefaultInputDeviceID() -> AudioDeviceID {
        return getUInt32Property(kAudioHardwarePropertyDefaultInputDevice, of: AudioObjectID(kAudioObjectSystemObject))!
    }

    func setDefaultInputDevice(_ id: AudioDeviceID) -> OSStatus {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = id
        return AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size), &deviceID
        )
    }

    func startObserving(_ onChange: @escaping () -> Void) {
        let listener: AudioObjectPropertyListenerBlock = { _, _ in onChange() }
        self.listener = listener

        for selector in Self.observedProperties {
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            let status = AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
            precondition(status == noErr, "Couldn't observe audio inputs: \(status)")
        }
    }

    func stopObserving() {
        guard let listener else { return }

        for selector in Self.observedProperties {
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            let status = AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
            precondition(status == noErr, "Couldn't stop observing audio inputs: \(status)")
        }
        self.listener = nil
    }

    private func getInputDevice(_ id: AudioDeviceID) -> AudioInputDevice? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size)
        if status != noErr { return nil }
        if size == 0 { return nil }

        let isAlive = getUInt32Property(kAudioDevicePropertyDeviceIsAlive, of: id)
        if isAlive != 1 { return nil }

        guard let transport = getUInt32Property(kAudioDevicePropertyTransportType, of: id) else { return nil }
        guard let uid = getStringProperty(kAudioDevicePropertyDeviceUID, of: id) else { return nil }
        guard let name = getStringProperty(kAudioObjectPropertyName, of: id) else { return nil }

        let isIPhone: Bool
        switch transport {
        case kAudioDeviceTransportTypeContinuityCaptureWired, kAudioDeviceTransportTypeContinuityCaptureWireless:
            isIPhone = true
        default:
            isIPhone = false
        }
        return AudioInputDevice(id: id, uid: uid, name: name, isIPhone: isIPhone)
    }

    private func getUInt32Property(_ selector: AudioObjectPropertySelector, of id: AudioObjectID) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
        if status != noErr { return nil }
        return value
    }

    private func getStringProperty(_ selector: AudioObjectPropertySelector, of id: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
        if status != noErr { return nil }
        return value!.takeRetainedValue() as String
    }
}
