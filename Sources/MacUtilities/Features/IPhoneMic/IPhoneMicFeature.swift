import AppKit
import Combine
import CoreAudio
import SwiftUI

final class IPhoneMicFeature: Feature, ObservableObject {
    let identifier = "iphone-mic"
    let displayName = "iPhone Mic"
    let summary = "Uses your nearby iPhone as the Mac's default microphone."
    let iconSymbolName = "mic.fill"
    let iconGradient = Gradient(colors: [.cyan, .blue])

    private let audioInput: AudioInput

    @Published private var inputDevices: [AudioInputDevice] = []
    @Published private var defaultInputDeviceID = AudioDeviceID(kAudioObjectUnknown)
    @Published private var session: IPhoneMicSession?
    @Published private var errorMessage: String?

    init(audioInput: AudioInput = SystemAudioInput()) {
        self.audioInput = audioInput
    }

    func start() {
        audioInput.startObserving { [weak self] in self?.refresh() }
        refresh()
    }

    func stop() {
        turnOff()
        audioInput.stopObserving()
    }

    @MainActor func prepareForTermination() async {
        turnOff()
    }

    func handle(type: CGEventType, event: CGEvent) -> Bool {
        return false
    }

    func buildSettingsSections() -> AnyView {
        return AnyView(IPhoneMicSettingsView(feature: self))
    }

    func buildPopoverTile() -> AnyView? {
        return AnyView(IPhoneMicTile(feature: self))
    }

    func toggle() {
        if session != nil {
            turnOff()
            return
        }
        turnOn()
    }

    var defaultInput: AudioInputDevice? {
        return inputDevices.first { $0.id == defaultInputDeviceID }
    }

    var isIPhoneSelected: Bool {
        return defaultInput?.isIPhone == true
    }

    var canToggle: Bool {
        if session != nil { return true }
        if isIPhoneSelected { return false }
        return iPhone != nil
    }

    var statusText: String {
        if let errorMessage { return errorMessage }
        if let session { return "Using \(session.iPhone.name)" }
        if isIPhoneSelected { return "iPhone already selected" }
        guard let iPhone else { return "No iPhone available" }
        return "Ready · \(iPhone.name)"
    }

    private var iPhone: AudioInputDevice? {
        return inputDevices.first { $0.isIPhone }
    }

    private func turnOn() {
        refresh()
        errorMessage = nil

        guard let iPhone else { return }
        if isIPhoneSelected { return }

        let previousInputUID = defaultInput?.uid
        let status = audioInput.setDefaultInputDevice(iPhone.id)
        if status != noErr {
            errorMessage = "Couldn't select iPhone microphone (error \(status))."
            return
        }

        session = IPhoneMicSession(iPhone: iPhone, previousInputUID: previousInputUID)
        refresh()
    }

    private func turnOff() {
        refresh()
        errorMessage = nil

        guard let session else { return }
        guard let previousInputUID = session.previousInputUID else {
            errorMessage = "No previous microphone to restore. Choose another input in Sound settings."
            return
        }
        guard let restoredInput = inputDevices.first(where: { $0.uid == previousInputUID }) else {
            errorMessage = "Previous microphone disconnected. Choose another input in Sound settings."
            return
        }

        let status = audioInput.setDefaultInputDevice(restoredInput.id)
        if status != noErr {
            errorMessage = "Couldn't restore previous microphone (error \(status))."
            return
        }

        self.session = nil
        refresh()
    }

    private func refresh() {
        inputDevices = audioInput.getInputDevices()
        defaultInputDeviceID = audioInput.getDefaultInputDeviceID()

        guard let session else { return }
        if isSessionInputSelected(session) { return }
        self.session = nil
        errorMessage = nil
    }

    private func isSessionInputSelected(_ session: IPhoneMicSession) -> Bool {
        if defaultInputDeviceID != session.iPhone.id { return false }
        if !inputDevices.contains(where: { $0.uid == session.iPhone.uid }) { return false }
        return true
    }
}
