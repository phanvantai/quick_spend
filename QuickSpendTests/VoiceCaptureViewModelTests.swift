import Testing
import Foundation
@testable import QuickSpend

private typealias AppCategory = QuickSpend.Category

@MainActor
private final class MockParser: ExpenseParsing {
    var stubbedResults: [ParsedTransaction] = []
    var callCount = 0
    var capturedInput: String?
    var capturedLanguage: String?
    var capturedCurrency: String?

    func parse(
        input: String,
        categories: [QuickSpend.Category],
        language: String,
        currency: String,
        usageLimitService: UsageLimitService
    ) async -> [ParsedTransaction] {
        callCount += 1
        capturedInput = input
        capturedLanguage = language
        capturedCurrency = currency
        return stubbedResults
    }
}

/// Covers the parse + state-machine paths in VoiceCaptureViewModel.
///
/// Recording-start auth/voice paths aren't exercised here — they would
/// require mocking VoiceService (currently concrete). The gating logic that
/// runs BEFORE voice service contact (limit check) is still covered.
@Suite("VoiceCaptureViewModel Tests")
@MainActor
struct VoiceCaptureViewModelTests {

    private func makeUsage(_ suite: String = UUID().uuidString) -> UsageLimitService {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return UsageLimitService(defaults: defaults)
    }

    private func makePrefs(_ suite: String = UUID().uuidString) -> PreferencesService {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return PreferencesService(defaults: defaults)
    }

    private func makeViewModel(parser: MockParser? = nil) -> VoiceCaptureViewModel {
        VoiceCaptureViewModel(
            voiceService: VoiceService(),
            usageLimitService: makeUsage(),
            preferences: makePrefs(),
            parser: parser ?? MockParser()
        )
    }

    // MARK: - Initial state

    @Test("Initial state — all flags off, collections empty")
    func testInitialState() {
        let vm = makeViewModel()

        #expect(vm.isRecordingActive == false)
        #expect(vm.isProcessingVoice == false)
        #expect(vm.isDragCancelling == false)
        #expect(vm.parsedTransactions.isEmpty)
        #expect(vm.fallbackTranscription == "")
        #expect(vm.showTransactionReview == false)
        #expect(vm.showLimitReachedAlert == false)
        #expect(vm.showManualFallback == false)
        #expect(vm.showParseFailureToast == false)
        #expect(vm.isBlocked == false)
        #expect(vm.isRecordingOrListening == false)
    }

    // MARK: - processTranscription

    @Test("processTranscription with empty/whitespace input is a no-op")
    func testEmptyTranscriptionNoOp() async {
        let parser = MockParser()
        let vm = makeViewModel(parser: parser)

        let task = vm.processTranscription("   \n  ")
        #expect(task == nil)
        #expect(parser.callCount == 0)
        #expect(vm.isProcessingVoice == false)
        #expect(vm.showTransactionReview == false)
    }

    @Test("processTranscription with non-empty input + parser results populates parsedTransactions and shows review")
    func testSuccessfulParse() async {
        let parser = MockParser()
        parser.stubbedResults = [
            ParsedTransaction(
                amount: 50_000,
                note: "coffee",
                categoryId: "food",
                type: .expense,
                date: Date(),
                confidence: 0.95
            )
        ]
        let vm = makeViewModel(parser: parser)
        vm.language = "vi"
        vm.currency = "VND"
        vm.isPremium = true   // skip limit gate

        let task = vm.processTranscription("Coffee 50k")
        await task?.value

        #expect(parser.callCount == 1)
        #expect(parser.capturedInput == "Coffee 50k")
        #expect(parser.capturedLanguage == "vi")
        #expect(parser.capturedCurrency == "VND")
        #expect(vm.parsedTransactions.count == 1)
        #expect(vm.parsedTransactions[0].rawInput == "Coffee 50k")
        #expect(vm.showTransactionReview == true)
        #expect(vm.isProcessingVoice == false)
        #expect(vm.showManualFallback == false)
    }

    @Test("processTranscription falls back to manual entry when parser returns no results")
    func testParseFailureFallsBack() async {
        let parser = MockParser()
        parser.stubbedResults = []
        let vm = makeViewModel(parser: parser)
        vm.isPremium = true

        let task = vm.processTranscription("unparseable nonsense")
        await task?.value

        #expect(parser.callCount == 1)
        #expect(vm.parsedTransactions.isEmpty)
        #expect(vm.fallbackTranscription == "unparseable nonsense")
        #expect(vm.showManualFallback == true)
        #expect(vm.showTransactionReview == false)
        #expect(vm.showParseFailureToast == true)
        #expect(vm.isProcessingVoice == false)
    }

    @Test("processTranscription truncates input above maxVoiceInputLength")
    func testTruncatesLongInput() async {
        let parser = MockParser()
        parser.stubbedResults = [
            ParsedTransaction(
                amount: 1,
                note: "y",
                categoryId: "x",
                type: .expense,
                date: Date(),
                confidence: 0.5
            )
        ]
        let vm = makeViewModel(parser: parser)
        vm.isPremium = true

        let long = String(repeating: "a", count: AppConstants.maxVoiceInputLength + 50)
        let task = vm.processTranscription(long)
        await task?.value

        #expect(parser.capturedInput?.count == AppConstants.maxVoiceInputLength)
    }

    // MARK: - Limit gating

    @Test("processTranscription with limit reached + non-premium shows limit alert and does NOT call parser")
    func testLimitGateBlocksParse() {
        let parser = MockParser()
        let usage = makeUsage()
        let vm = VoiceCaptureViewModel(
            voiceService: VoiceService(),
            usageLimitService: usage,
            preferences: makePrefs(),
            parser: parser
        )
        vm.isPremium = false

        // Burn through the daily limit so hasReachedLimit returns true.
        for _ in 0..<AppConstants.freeTierGeminiLimit {
            usage.incrementUsage()
        }
        #expect(usage.hasReachedLimit == true)

        let task = vm.processTranscription("anything")

        #expect(task == nil)
        #expect(parser.callCount == 0)
        #expect(vm.showLimitReachedAlert == true)
        #expect(vm.fallbackTranscription == "anything")
        #expect(vm.isProcessingVoice == false)
    }

    @Test("handleRecordStart with limit reached + non-premium shows limit alert and does not touch voice")
    func testHandleRecordStartLimitGate() {
        let usage = makeUsage()
        let vm = VoiceCaptureViewModel(
            voiceService: VoiceService(),
            usageLimitService: usage,
            preferences: makePrefs(),
            parser: MockParser()
        )
        vm.isPremium = false

        for _ in 0..<AppConstants.freeTierGeminiLimit { usage.incrementUsage() }

        vm.handleRecordStart()

        #expect(vm.showLimitReachedAlert == true)
        #expect(vm.isRecordingActive == false)
    }

    // MARK: - Premium toggle

    @Test("Setting isPremium mirrors to usageLimitService")
    func testIsPremiumMirrors() {
        let usage = makeUsage()
        let vm = VoiceCaptureViewModel(
            voiceService: VoiceService(),
            usageLimitService: usage,
            preferences: makePrefs(),
            parser: MockParser()
        )

        #expect(usage.isPremium == false)
        vm.isPremium = true
        #expect(usage.isPremium == true)
        vm.isPremium = false
        #expect(usage.isPremium == false)
    }

    // MARK: - syncWithVoiceServiceListeningState

    @Test("syncWithVoiceServiceListeningState clears isRecordingActive when service stopped")
    func testSyncClearsStaleRecording() {
        let vm = makeViewModel()
        // Simulate stale FAB state without service listening.
        vm.isRecordingActive = true
        // voiceService.isListening starts false; sync should clear the flag.
        vm.syncWithVoiceServiceListeningState()
        #expect(vm.isRecordingActive == false)
    }
}
