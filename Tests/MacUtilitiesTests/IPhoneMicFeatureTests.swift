import CoreAudio
import Testing
@testable import MacUtilities

struct IPhoneMicFeatureTests {
    private let builtIn = AudioInputDevice(id: 1, uid: "built-in", name: "Mac microphone", isIPhone: false)
    private let iPhone = AudioInputDevice(id: 2, uid: "iphone", name: "My iPhone Microphone", isIPhone: true)
    private let headset = AudioInputDevice(id: 3, uid: "headset", name: "Headset", isIPhone: false)

    @Test
    func enablingFeatureOnlyObservesInputs() {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)

        feature.start()

        #expect(audioInput.onChange != nil)
        #expect(audioInput.selectedDeviceIDs.isEmpty)
        #expect(feature.canToggle)
        #expect(feature.statusText == "Ready · \(iPhone.name)")
        #expect(feature.defaultInput == builtIn)
        #expect(!feature.isIPhoneSelected)
    }

    @Test
    func toggleSelectsIPhoneAndRestoresPreviousInput() {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()

        feature.toggle()

        #expect(feature.canToggle)
        #expect(feature.defaultInput == iPhone)
        #expect(feature.isIPhoneSelected)

        feature.toggle()

        #expect(audioInput.selectedDeviceIDs == [iPhone.id, builtIn.id])
        #expect(feature.defaultInput == builtIn)
        #expect(!feature.isIPhoneSelected)
    }

    @Test
    func disablingFeatureRestoresInputAndStopsObserving() {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()

        feature.stop()

        #expect(audioInput.defaultInputDeviceID == builtIn.id)
        #expect(audioInput.onChange == nil)
        #expect(!feature.isIPhoneSelected)
    }

    @Test @MainActor
    func terminationRestoresInputAfterFeatureWasDisabled() async {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()
        audioInput.selectionStatus = kAudioHardwareUnspecifiedError
        feature.stop()
        #expect(feature.isIPhoneSelected)

        audioInput.selectionStatus = noErr
        await feature.prepareForTermination()

        #expect(audioInput.defaultInputDeviceID == builtIn.id)
        #expect(!feature.isIPhoneSelected)
    }

    @Test
    func externalSelectionReleasesControlWithoutRestoring() {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone, headset], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()

        audioInput.defaultInputDeviceID = headset.id
        audioInput.onChange!()
        feature.stop()

        #expect(!feature.isIPhoneSelected)
        #expect(audioInput.selectedDeviceIDs == [iPhone.id])
        #expect(audioInput.defaultInputDeviceID == headset.id)
    }

    @Test
    func disconnectReleasesControlAndReconnectDoesNotSelectAutomatically() {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()

        audioInput.devices = [builtIn]
        audioInput.onChange!()
        #expect(!feature.isIPhoneSelected)
        #expect(!feature.canToggle)

        audioInput.defaultInputDeviceID = builtIn.id
        audioInput.devices = [builtIn, iPhone]
        audioInput.onChange!()

        #expect(feature.canToggle)
        #expect(!feature.isIPhoneSelected)
        #expect(audioInput.selectedDeviceIDs == [iPhone.id])
    }

    @Test
    func restorationUsesPersistentDeviceIdentifierAfterReconnect() {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()

        let reconnectedInput = AudioInputDevice(id: 4, uid: builtIn.uid, name: builtIn.name, isIPhone: false)
        audioInput.devices = [reconnectedInput, iPhone]
        feature.toggle()

        #expect(audioInput.defaultInputDeviceID == reconnectedInput.id)
        #expect(!feature.isIPhoneSelected)
    }

    @Test
    func failedSelectionLeavesPreviousInputAndPermitsRetry() {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        audioInput.selectionStatus = kAudioHardwareUnspecifiedError

        feature.toggle()

        #expect(!feature.isIPhoneSelected)
        #expect(feature.statusText.hasPrefix("Couldn't select iPhone microphone"))
        #expect(feature.defaultInput == builtIn)

        audioInput.selectionStatus = noErr
        feature.toggle()

        #expect(feature.isIPhoneSelected)
        #expect(feature.statusText == "Using \(iPhone.name)")
    }

    @Test
    func failedRestorationKeepsSessionForRetry() {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()
        audioInput.selectionStatus = kAudioHardwareUnspecifiedError

        feature.toggle()

        #expect(feature.isIPhoneSelected)
        #expect(feature.canToggle)
        #expect(feature.statusText.hasPrefix("Couldn't restore previous microphone"))
        #expect(feature.defaultInput == iPhone)

        audioInput.selectionStatus = noErr
        feature.toggle()

        #expect(!feature.isIPhoneSelected)
        #expect(feature.statusText == "Ready · \(iPhone.name)")
        #expect(feature.defaultInput == builtIn)
    }

    @Test
    func missingPreviousInputShowsMessageAndPreservesIPhoneSelection() {
        let audioInput = FakeAudioInput(devices: [builtIn, iPhone], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()
        feature.toggle()

        audioInput.devices = [iPhone]
        feature.toggle()

        #expect(audioInput.selectedDeviceIDs == [iPhone.id])
        #expect(feature.isIPhoneSelected)
        #expect(feature.canToggle)
        #expect(feature.statusText.hasPrefix("Previous microphone disconnected"))
    }

    @Test
    func iPhoneCanBeSelectedWhenMacHasNoOtherMicrophone() {
        let audioInput = FakeAudioInput(devices: [iPhone], defaultInputDeviceID: AudioDeviceID(kAudioObjectUnknown))
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()

        feature.toggle()
        #expect(feature.defaultInput == iPhone)

        feature.toggle()
        #expect(feature.isIPhoneSelected)
        #expect(feature.canToggle)
        #expect(feature.statusText.hasPrefix("No previous microphone to restore"))
        #expect(audioInput.selectedDeviceIDs == [iPhone.id])
    }

    @Test
    func unavailableOrAlreadySelectedIPhoneDoesNotChangeInput() {
        let audioInput = FakeAudioInput(devices: [builtIn], defaultInputDeviceID: builtIn.id)
        let feature = IPhoneMicFeature(audioInput: audioInput)
        feature.start()

        feature.toggle()
        #expect(!feature.canToggle)
        #expect(audioInput.selectedDeviceIDs.isEmpty)

        audioInput.devices = [builtIn, iPhone]
        audioInput.defaultInputDeviceID = iPhone.id
        audioInput.onChange!()
        feature.toggle()

        #expect(!feature.canToggle)
        #expect(feature.isIPhoneSelected)
        #expect(audioInput.selectedDeviceIDs.isEmpty)
    }
}
