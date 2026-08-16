import Foundation
import Speech
import AVFoundation

/// Push-to-talk dictation using Apple's on-device Speech framework — zero extra
/// dependencies, works offline for most locales, ships in the MVP scaffold.
///
/// Sentio's iOS app solved this same "voice → agent" problem with WhisperKit for
/// higher-accuracy, fully-offline transcription (see WhisperKitService.swift /
/// LiveTranscriptionService.swift in sentio-ios-app-v2). That's the natural upgrade
/// path here once voice quality is being tuned for real organizer use — swapping the
/// transcript source doesn't change anything downstream, every screen here only ever
/// consumes a finished `String` from this service.
@MainActor
final class VoiceCaptureService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var authorizationError: String?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in continuation.resume(returning: status) }
        }
        guard speechStatus == .authorized else {
            authorizationError = "Speech recognition access is required to talk to the agent."
            return false
        }
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            authorizationError = "Microphone access is required to talk to the agent."
            return false
        }
        return true
    }

    func startRecording() throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        transcript = ""

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Keeps the whole utterance on-device when the recognizer supports it — an
        // organizer dictating agenda details out loud shouldn't leave the device.
        if #available(iOS 13, *) { request.requiresOnDeviceRecognition = recognizer?.supportsOnDeviceRecognition ?? false }
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            authorizationError = "Microphone audio is unavailable. Check microphone permission and try again."
            recognitionRequest = nil
            isRecording = false
            return
        }

        recognitionRequest = request
        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in self.transcript = result.bestTranscription.formattedString }
            }
            if error != nil || (result?.isFinal ?? false) {
                inputNode.removeTap(onBus: 0)
                self.audioEngine.stop()
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }

        // AVAudioEngine raises an Objective-C exception if a prior tap is still
        // installed. Removing it is safe when there is no existing tap.
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        HapticManager.shared.recordStart()
    }

    func stopRecording() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
        HapticManager.shared.recordStop()
    }
}
