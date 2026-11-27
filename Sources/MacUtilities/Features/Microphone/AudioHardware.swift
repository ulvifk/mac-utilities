import CoreAudio

/// The CoreAudio properties SystemAudioInput reads, sets and observes, so its selection logic runs without real hardware.
protocol AudioHardware {
    /// Every audio device, inputs and outputs alike.
    func getDeviceIDs() -> [AudioDeviceID]
    func getDefaultInputDeviceID() -> AudioDeviceID
    /// Asks for the change; the default input changes once its listener reports it, or not at all.
    func setDefaultInputDevice(_ id: AudioDeviceID) -> OSStatus
    func hasInputStreams(_ id: AudioDeviceID) -> Bool
    func isAlive(_ id: AudioDeviceID) -> Bool
    /// Stable across reconnects, unlike the device ID; nil when the device is gone.
    func getUID(_ id: AudioDeviceID) -> String?
    func getName(_ id: AudioDeviceID) -> String?
    /// Calls the listener on the main queue when the device list or the default input changes.
    func addListener(_ listener: @escaping AudioObjectPropertyListenerBlock)
    func removeListener(_ listener: @escaping AudioObjectPropertyListenerBlock)
}
