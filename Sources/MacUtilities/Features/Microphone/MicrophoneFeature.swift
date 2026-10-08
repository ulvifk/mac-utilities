import AppKit
import Combine
import CoreAudio
import SwiftUI

final class MicrophoneFeature: Feature, ObservableObject {
    let identifier = "microphone"
    let displayName = "Microphone"
    let summary = "Chooses the Mac's default microphone from connected audio inputs."
    let iconSymbolName = "mic.fill"
    let iconGradient = Gradient(colors: [.cyan, .blue])

    private let audioInput: AudioInput

    @Published private(set) var inputDevices: [AudioInputDevice] = []
    @Published private var defaultInputDeviceID = AudioDeviceID(kAudioObjectUnknown)
    @Published private var session: MicrophoneSession?
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
        changeInput(to: nil)
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
        return AnyView(MicrophoneSettingsView(feature: self))
    }

    func buildPopoverTile() -> AnyView? {
        return AnyView(MicrophoneTile(feature: self))
    }

    func selectInput(_ uid: String) {
        if !canSelect { return }
        changeInput(to: uid)
    }

    func restorePreviousInput() {
        if !canRestore { return }
        changeInput(to: nil)
    }

    var defaultInput: AudioInputDevice? {
        return inputDevices.first { $0.id == defaultInputDeviceID }
    }

    var isActive: Bool {
        return session != nil
    }

    var canSelect: Bool {
        if !isEnabled { return false }
        if isTerminating { return false }
        if transition != nil { return false }
        return !inputDevices.isEmpty
    }

    var canRestore: Bool {
        if !canSelect { return false }
        return isActive
    }

    var statusText: String {
        if transition != nil { return "Switching microphone…" }
        if let errorMessage { return errorMessage }
        guard let defaultInput else { return "No microphone selected" }
        return "Using \(defaultInput.name)"
    }

    private func changeInput(to uid: String?) {
        if transition != nil { return }

        transition = Task { @MainActor in
            if let uid {
                await selectInputDevice(uid)
                if !isEnabled { await turnOff() }
            } else {
                await turnOff()
            }

            if !isEnabled { audioInput.stopObserving() }
            transition = nil
        }
    }

    @MainActor private func selectInputDevice(_ uid: String) async {
        refresh()
        errorMessage = nil

        guard let input = inputDevices.first(where: { $0.uid == uid }) else { return }
        if defaultInput?.uid == uid { return }

        let previousInputUID: String?
        if let session {
            previousInputUID = session.previousInputUID
        } else {
            previousInputUID = defaultInput?.uid
        }

        let status = await audioInput.setDefaultInputDevice(input.id)
        if status != noErr {
            errorMessage = "Couldn't select microphone (error \(status))."
            return
        }

        session = MicrophoneSession(selectedInputUID: uid, previousInputUID: previousInputUID)
        refresh()
    }

    @MainActor private func turnOff() async {
        refresh()
        errorMessage = nil

        guard let session else { return }
        guard let previousInputUID = session.previousInputUID else {
            errorMessage = "No previous microphone to restore. Choose another input."
            return
        }
        guard let restoredInput = inputDevices.first(where: { $0.uid == previousInputUID }) else {
            errorMessage = "Previous microphone disconnected. Choose another input."
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
        if defaultInput?.uid == session.selectedInputUID { return }
        self.session = nil
        errorMessage = nil
    }
}
