import CoreAudio
import Foundation

private let observedProperties = [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultInputDevice]
private let systemObjectID = AudioObjectID(kAudioObjectSystemObject)

final class SystemAudioHardware: AudioHardware {
    func getDeviceIDs() -> [AudioDeviceID] {
        var address = buildGlobalAddress(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(systemObjectID, &address, 0, nil, &size)
        precondition(sizeStatus == noErr, "Couldn't read audio device list size: \(sizeStatus)")

        var deviceIDs = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        let devicesStatus = deviceIDs.withUnsafeMutableBytes { buffer in
            AudioObjectGetPropertyData(systemObjectID, &address, 0, nil, &size, buffer.baseAddress!)
        }
        precondition(devicesStatus == noErr, "Couldn't read audio devices: \(devicesStatus)")

        return deviceIDs
    }

    func getDefaultInputDeviceID() -> AudioDeviceID {
        return getUInt32Property(kAudioHardwarePropertyDefaultInputDevice, of: systemObjectID)!
    }

    func setDefaultInputDevice(_ id: AudioDeviceID) -> OSStatus {
        var address = buildGlobalAddress(kAudioHardwarePropertyDefaultInputDevice)
        var deviceID = id

        return AudioObjectSetPropertyData(systemObjectID, &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &deviceID)
    }

    func hasInputStreams(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size)
        if status != noErr { return false }

        return size > 0
    }

    func isAlive(_ id: AudioDeviceID) -> Bool {
        return getUInt32Property(kAudioDevicePropertyDeviceIsAlive, of: id) == 1
    }

    func getUID(_ id: AudioDeviceID) -> String? {
        return getStringProperty(kAudioDevicePropertyDeviceUID, of: id)
    }

    func getName(_ id: AudioDeviceID) -> String? {
        return getStringProperty(kAudioObjectPropertyName, of: id)
    }

    func addListener(_ listener: @escaping AudioObjectPropertyListenerBlock) {
        for selector in observedProperties {
            var address = buildGlobalAddress(selector)
            let status = AudioObjectAddPropertyListenerBlock(systemObjectID, &address, .main, listener)
            precondition(status == noErr, "Couldn't observe audio inputs: \(status)")
        }
    }

    func removeListener(_ listener: @escaping AudioObjectPropertyListenerBlock) {
        for selector in observedProperties {
            var address = buildGlobalAddress(selector)
            let status = AudioObjectRemovePropertyListenerBlock(systemObjectID, &address, .main, listener)
            precondition(status == noErr, "Couldn't stop observing audio inputs: \(status)")
        }
    }

    private func getUInt32Property(_ selector: AudioObjectPropertySelector, of id: AudioObjectID) -> UInt32? {
        var address = buildGlobalAddress(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
        if status != noErr { return nil }
        return value
    }

    private func getStringProperty(_ selector: AudioObjectPropertySelector, of id: AudioObjectID) -> String? {
        var address = buildGlobalAddress(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
        if status != noErr { return nil }
        return value!.takeRetainedValue() as String
    }
}

private func buildGlobalAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    return AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
}
