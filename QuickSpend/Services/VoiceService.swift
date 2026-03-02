import Foundation
import Speech
import AVFoundation

/// Speech recognition service using SFSpeechRecognizer + AVAudioEngine
@Observable
final class VoiceService {
    private var speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private(set) var isListening = false
    private(set) var transcription = ""
    private(set) var soundLevel: Float = 0

    /// Authorization status
    var isAuthorized: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
            && AVAudioApplication.shared.recordPermission == .granted
    }

    /// Request both speech recognition and microphone permissions
    func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechStatus else { return false }

        let micStatus = await AVAudioApplication.requestRecordPermission()
        return micStatus
    }

    /// Start listening for speech in the given language
    func startListening(language: String) throws {
        guard !isListening else { return }

        // Cancel any previous task
        stopListening()

        let locale = Locale(identifier: localeIdentifier(for: language))
        speechRecognizer = SFSpeechRecognizer(locale: locale)

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            print("[VoiceService] Speech recognizer not available for \(locale)")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // Calculate sound level from buffer
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            if let channelData, frameLength > 0 {
                var sum: Float = 0
                for i in 0..<frameLength {
                    sum += abs(channelData[i])
                }
                let average = sum / Float(frameLength)
                // Normalize to 0-1 range (typical speech is 0.01-0.1)
                let normalized = min(average * 10, 1.0)
                DispatchQueue.main.async {
                    self?.soundLevel = normalized
                }
            }
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            if let result {
                DispatchQueue.main.async {
                    self.transcription = result.bestTranscription.formattedString
                }
            }

            if error != nil || result?.isFinal == true {
                DispatchQueue.main.async {
                    self.isListening = false
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
        transcription = ""
        soundLevel = 0
    }

    /// Stop listening and return the final transcription
    @discardableResult
    func stopListening() -> String {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        isListening = false
        soundLevel = 0

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        return transcription
    }

    /// Cancel listening and discard transcription
    func cancelListening() {
        stopListening()
        transcription = ""
    }

    // MARK: - Locale Mapping

    private func localeIdentifier(for language: String) -> String {
        language == "vi" ? "vi-VN" : "en-US"
    }
}
