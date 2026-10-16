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

    @Test("processTranscription with an uncertain parse populates parsedTransactions and shows review")
    func testSuccessfulParse() async {
        let parser = MockParser()
        parser.stubbedResults = [
            ParsedTransaction(
                amount: 50_000,
                note: "coffee",
                categoryId: "food",
                type: .expense,
                date: Date(),
                confidence: 0.8
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

    // MARK: - Hands-free (widget / Control Center launch)

    @Test("Hands-free start with limit reached shows the limit alert and stays idle")
    func testHandsFreeStartLimitGate() {
        let usage = makeUsage()
        let vm = VoiceCaptureViewModel(
            voiceService: VoiceService(),
            usageLimitService: usage,
            preferences: makePrefs(),
            parser: MockParser()
        )
        vm.isPremium = false
        for _ in 0..<AppConstants.freeTierGeminiLimit { usage.incrementUsage() }

        vm.startHandsFreeRecording()

        #expect(vm.showLimitReachedAlert == true)
        #expect(vm.isHandsFree == false)
        #expect(vm.isRecordingActive == false)
    }

    @Test("Hands-free start is ignored while a capture is being processed")
    func testHandsFreeStartWhileProcessing() {
        let vm = makeViewModel()
        vm.isProcessingVoice = true

        vm.startHandsFreeRecording()

        #expect(vm.isHandsFree == false)
        #expect(vm.isRecordingActive == false)
    }

    @Test("Finishing or cancelling hands-free mode clears it")
    func testHandsFreeFinishAndCancelClearMode() {
        let vm = makeViewModel()
        vm.isHandsFree = true
        vm.finishHandsFreeRecording()
        #expect(vm.isHandsFree == false)

        vm.isHandsFree = true
        vm.cancelHandsFreeRecording()
        #expect(vm.isHandsFree == false)
    }

    @Test("When the recognizer stops by itself in hands-free mode, the session ends")
    func testHandsFreeAutoStopEndsSession() {
        let vm = makeViewModel()
        vm.isHandsFree = true
        vm.isRecordingActive = true

        // voiceService.isListening is false, as after a final result or timeout.
        vm.syncWithVoiceServiceListeningState()

        #expect(vm.isHandsFree == false)
        #expect(vm.isRecordingActive == false)
    }

    // MARK: - Auto-save (same rule as the Siri flow)

    private func makeParsed(note: String = "coffee test", confidence: Double) -> ParsedTransaction {
        ParsedTransaction(
            amount: 50_000,
            note: note,
            categoryId: "food_drink",
            type: .expense,
            date: Date(timeIntervalSince1970: 1_900_000_000),
            confidence: confidence
        )
    }

    @Test("A confident parse is saved right away to the default wallet and shows the saved toast")
    func testConfidentParseAutoSaves() async {
        let parser = MockParser()
        parser.stubbedResults = [makeParsed(confidence: 0.95), makeParsed(note: "bread test", confidence: 0.9)]
        let vm = makeViewModel(parser: parser)
        vm.isPremium = true
        vm.defaultWalletId = "wallet_default_test"
        var saved: [Transaction] = []
        vm.onAutoSave = { saved = $0 }

        await vm.processTranscription("coffee and bread")?.value

        #expect(saved.count == 2)
        #expect(saved.allSatisfy { $0.walletId == "wallet_default_test" })
        #expect(saved.allSatisfy { $0.rawInput == "coffee and bread" })
        #expect(saved.map(\.note) == ["coffee test", "bread test"])
        #expect(saved[0].confidence == 0.95)
        #expect(vm.showTransactionReview == false)
        #expect(vm.showAutoSavedToast == true)
        #expect(vm.autoSavedTransactions.count == 2)
        #expect(vm.parsedTransactions.isEmpty)
    }

    @Test("One uncertain item sends the whole batch to review")
    func testOneUncertainItemShowsReview() async {
        let parser = MockParser()
        parser.stubbedResults = [makeParsed(confidence: 0.95), makeParsed(confidence: 0.89)]
        let vm = makeViewModel(parser: parser)
        vm.isPremium = true
        var autoSaveCalls = 0
        vm.onAutoSave = { _ in autoSaveCalls += 1 }

        await vm.processTranscription("coffee and something")?.value

        #expect(autoSaveCalls == 0)
        #expect(vm.showTransactionReview == true)
        #expect(vm.showAutoSavedToast == false)
        #expect(vm.parsedTransactions.count == 2)
    }

    @Test("If the auto-save fails, the parse falls back to review so nothing is lost")
    func testAutoSaveFailureFallsBackToReview() async {
        struct SaveFailure: Error {}
        let parser = MockParser()
        parser.stubbedResults = [makeParsed(confidence: 0.97)]
        let vm = makeViewModel(parser: parser)
        vm.isPremium = true
        vm.onAutoSave = { _ in throw SaveFailure() }

        await vm.processTranscription("coffee")?.value

        #expect(vm.showTransactionReview == true)
        #expect(vm.showAutoSavedToast == false)
        #expect(vm.parsedTransactions.count == 1)
    }

    @Test("Without a save handler a confident parse still goes to review")
    func testNoSaveHandlerShowsReview() async {
        let parser = MockParser()
        parser.stubbedResults = [makeParsed(confidence: 0.99)]
        let vm = makeViewModel(parser: parser)
        vm.isPremium = true

        await vm.processTranscription("coffee")?.value

        #expect(vm.showTransactionReview == true)
        #expect(vm.showAutoSavedToast == false)
    }

    @Test("In-app and Siri use the same auto-save rule")
    func testSharedAutoSaveRule() {
        let confident = [makeParsed(confidence: 0.9)]
        let uncertain = [makeParsed(confidence: 0.95), makeParsed(confidence: 0.5)]
        #expect(VoiceAutoSavePolicy.shouldAutoSave(confident) == AddExpenseIntent.shouldAutoSave(confident))
        #expect(VoiceAutoSavePolicy.shouldAutoSave(uncertain) == AddExpenseIntent.shouldAutoSave(uncertain))
        #expect(VoiceAutoSavePolicy.confidenceThreshold == AddExpenseIntent.autoSaveConfidenceThreshold)
    }
}
