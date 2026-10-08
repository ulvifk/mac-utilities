import CoreAudio
import Foundation

let audioHardware = FakeAudioHardware()

final class FakeAudioHardware {
    var devices: [AudioDeviceID] = [10, 20, 30]
    var outputOnlyDeviceIDs: [AudioDeviceID] = []
    var inactiveDeviceIDs: [AudioDeviceID] = []
    var currentDeviceID: AudioDeviceID = 10
    var requestedDeviceID: AudioDeviceID?
    var setterStatus: OSStatus = noErr
    var listeners: [AudioObjectPropertySelector: AudioObjectPropertyListenerBlock] = [:]

    func reset() {
        devices = [10, 20, 30]
        outputOnlyDeviceIDs = []
        inactiveDeviceIDs = []
        currentDeviceID = 10
        requestedDeviceID = nil
        setterStatus = noErr
        listeners = [:]
    }

    func notify(_ selector: AudioObjectPropertySelector) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        listeners[selector]!(1, &address)
    }
}

func AudioObjectGetPropertyDataSize(
    _ id: AudioObjectID, _ address: UnsafePointer<AudioObjectPropertyAddress>,
    _ qualifierSize: UInt32, _ qualifier: UnsafeRawPointer?, _ size: UnsafeMutablePointer<UInt32>
) -> OSStatus {
    switch address.pointee.mSelector {
    case kAudioHardwarePropertyDevices:
        size.pointee = UInt32(audioHardware.devices.count * MemoryLayout<AudioDeviceID>.size)
    case kAudioDevicePropertyStreams:
        size.pointee = audioHardware.outputOnlyDeviceIDs.contains(id) ? 0 : UInt32(MemoryLayout<UInt32>.size)
    default:
        preconditionFailure("Unexpected size query")
    }
    return noErr
}

func AudioObjectGetPropertyData(
    _ id: AudioObjectID, _ address: UnsafePointer<AudioObjectPropertyAddress>,
    _ qualifierSize: UInt32, _ qualifier: UnsafeRawPointer?,
    _ size: UnsafeMutablePointer<UInt32>, _ data: UnsafeMutableRawPointer
) -> OSStatus {
    switch address.pointee.mSelector {
    case kAudioHardwarePropertyDevices:
        audioHardware.devices.withUnsafeBytes { buffer in
            data.copyMemory(from: buffer.baseAddress!, byteCount: buffer.count)
        }
    case kAudioHardwarePropertyDefaultInputDevice:
        data.assumingMemoryBound(to: UInt32.self).pointee = audioHardware.currentDeviceID
    case kAudioDevicePropertyDeviceIsAlive:
        data.assumingMemoryBound(to: UInt32.self).pointee = audioHardware.inactiveDeviceIDs.contains(id) ? 0 : 1
    case kAudioDevicePropertyDeviceUID, kAudioObjectPropertyName:
        let value = "input-\(id)" as CFString
        data.assumingMemoryBound(to: Unmanaged<CFString>?.self).pointee = .passRetained(value)
    default:
        preconditionFailure("Unexpected property query")
    }
    return noErr
}

func AudioObjectSetPropertyData(
    _ id: AudioObjectID, _ address: UnsafePointer<AudioObjectPropertyAddress>,
    _ qualifierSize: UInt32, _ qualifier: UnsafeRawPointer?, _ size: UInt32, _ data: UnsafeRawPointer
) -> OSStatus {
    precondition(address.pointee.mSelector == kAudioHardwarePropertyDefaultInputDevice)
    audioHardware.requestedDeviceID = data.assumingMemoryBound(to: UInt32.self).pointee
    return audioHardware.setterStatus
}

func AudioObjectAddPropertyListenerBlock(
    _ id: AudioObjectID, _ address: UnsafePointer<AudioObjectPropertyAddress>,
    _ queue: DispatchQueue?, _ listener: @escaping AudioObjectPropertyListenerBlock
) -> OSStatus {
    audioHardware.listeners[address.pointee.mSelector] = listener
    return noErr
}

func AudioObjectRemovePropertyListenerBlock(
    _ id: AudioObjectID, _ address: UnsafePointer<AudioObjectPropertyAddress>,
    _ queue: DispatchQueue?, _ listener: @escaping AudioObjectPropertyListenerBlock
) -> OSStatus {
    audioHardware.listeners.removeValue(forKey: address.pointee.mSelector)
    return noErr
}
