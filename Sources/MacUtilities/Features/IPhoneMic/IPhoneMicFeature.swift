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
    @Published private var transition: Task<Void, Never>?

    private var isEnabled = false
    private var isTerminating = false

    init(audioInput: AudioInput = SystemAudioInput()) {
        self.audioInput = audioInput
    }

    func start() {
        if isTerminating { return }
        isEnabled = true
        if transition != nil { return }

        audioInput.startObserving { [weak self] in self?.refresh() }
        refresh()
    }

    func stop() {
        isEnabled = false
        changeInput(useIPhone: false)
    }

    @MainActor func prepareForTermination() async {
        isTerminating = true
        stop()
        await transition?.value
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
        if isTerminating { return }
        changeInput(useIPhone: session == nil)
    }

    var defaultInput: AudioInputDevice? {
        return inputDevices.first { $0.id == defaultInputDeviceID }
    }

    var isIPhoneSelected: Bool {
        return defaultInput?.isIPhone == true
    }

    var canToggle: Bool {
        if isTerminating { return false }
        if transition != nil { return false }
        if session != nil { return true }
        if isIPhoneSelected { return false }
        return iPhone != nil
    }

    var statusText: String {
        if transition != nil { return "Switching microphone…" }
        if let errorMessage { return errorMessage }
        if let session { return "Using \(session.iPhone.name)" }
        if isIPhoneSelected { return "iPhone already selected" }
        guard let iPhone else { return "No iPhone available" }
        return "Ready · \(iPhone.name)"
    }

    private var iPhone: AudioInputDevice? {
        return inputDevices.first { $0.isIPhone }
    }

    private func changeInput(useIPhone: Bool) {
        if transition != nil { return }

        transition = Task { @MainActor in
            if useIPhone {
                await turnOn()
                if !isEnabled { await turnOff() }
            } else {
                await turnOff()
            }

            if !isEnabled { audioInput.stopObserving() }
            transition = nil
        }
    }

    @MainActor private func turnOn() async {
        refresh()
        errorMessage = nil

        guard let iPhone else { return }
        if isIPhoneSelected { return }

        let previousInputUID = defaultInput?.uid
        let status = await audioInput.setDefaultInputDevice(iPhone.id)
        if status != noErr {
            errorMessage = "Couldn't select iPhone microphone (error \(status))."
            return
        }

        session = IPhoneMicSession(iPhone: iPhone, previousInputUID: previousInputUID)
        refresh()
    }

    @MainActor private func turnOff() async {
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

        let status = await audioInput.setDefaultInputDevice(restoredInput.id)
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
        if defaultInput?.uid == session.iPhone.uid { return }
        self.session = nil
        errorMessage = nil
    }
}
