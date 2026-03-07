import Testing
import Foundation
import Speech
import AVFoundation
@testable import QuickSpend

@Suite("VoiceService Tests")
struct VoiceServiceTests {

    // MARK: - Initial State

    @Test("Initial state: isListening is false")
    func testInitialIsListeningFalse() {
        let service = VoiceService()
        #expect(service.isListening == false)
    }

    @Test("Initial state: transcription is empty")
    func testInitialTranscriptionEmpty() {
        let service = VoiceService()
        #expect(service.transcription == "")
    }

    @Test("Initial state: soundLevel is zero")
    func testInitialSoundLevelZero() {
        let service = VoiceService()
        #expect(service.soundLevel == 0)
    }

    // MARK: - stopListening

    @Test("stopListening returns empty transcription when not started")
    func testStopListeningReturnsEmptyWhenNotStarted() {
        let service = VoiceService()
        let result = service.stopListening()
        #expect(result == "")
    }

    @Test("stopListening sets isListening to false")
    func testStopListeningSetsIsListeningFalse() {
        let service = VoiceService()
        _ = service.stopListening()
        #expect(service.isListening == false)
    }

    @Test("stopListening sets soundLevel to zero")
    func testStopListeningSetsSoundLevelZero() {
        let service = VoiceService()
        _ = service.stopListening()
        #expect(service.soundLevel == 0)
    }

    @Test("Multiple stopListening calls do not crash")
    func testMultipleStopCallsDoNotCrash() {
        let service = VoiceService()
        _ = service.stopListening()
        _ = service.stopListening()
        _ = service.stopListening()
        #expect(service.isListening == false)
        #expect(service.soundLevel == 0)
    }

    // MARK: - cancelListening

    @Test("cancelListening clears transcription")
    func testCancelListeningClearsTranscription() {
        let service = VoiceService()
        service.cancelListening()
        #expect(service.transcription == "")
    }

    @Test("cancelListening then stopListening does not crash")
    func testCancelThenStopDoesNotCrash() {
        let service = VoiceService()
        service.cancelListening()
        _ = service.stopListening()
        #expect(service.isListening == false)
        #expect(service.transcription == "")
        #expect(service.soundLevel == 0)
    }
}
