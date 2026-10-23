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
        wallets: [Wallet],
        defaultWalletId: String,
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

    private func makeViewModel(
        parser: MockParser? = nil,
        analytics: MockAnalyticsLogger = MockAnalyticsLogger(),
        samples: MockVoiceSampleRecorder? = nil,
        preferences: PreferencesService? = nil,
        appVersion: String = "9.9.9-test"
    ) -> VoiceCaptureViewModel {
        VoiceCaptureViewModel(
            voiceService: VoiceService(),
            usageLimitService: makeUsage(),
            preferences: preferences ?? makePrefs(),
            parser: parser ?? MockParser(),
            analytics: analytics,
            samples: samples ?? MockVoiceSampleRecorder(),
            appVersion: appVersion
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
            parser: parser,
            analytics: MockAnalyticsLogger(),
            samples: MockVoiceSampleRecorder()
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
            parser: MockParser(),
            analytics: MockAnalyticsLogger(),
            samples: MockVoiceSampleRecorder()
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
            parser: MockParser(),
            analytics: MockAnalyticsLogger(),
            samples: MockVoiceSampleRecorder()
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
            parser: MockParser(),
            analytics: MockAnalyticsLogger(),
            samples: MockVoiceSampleRecorder()
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
        #expect(vm.autoSavedItems.count == 2)
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

    @Test("A confident voice transfer is saved as two legs in one call")
    func testConfidentTransferAutoSaves() async {
        var transfer = makeParsed(note: "savings test", confidence: 0.95)
        transfer.categoryId = Transfer.categoryId
        transfer.walletId = "wallet_cash_test"
        transfer.transferToWalletId = "wallet_bank_test"
        let parser = MockParser()
        parser.stubbedResults = [transfer]
        let vm = makeViewModel(parser: parser)
        vm.isPremium = true
        var saved: [Transaction] = []
        vm.onAutoSave = { saved = $0 }

        await vm.processTranscription("move to savings")?.value

        #expect(saved.count == 2)
        #expect(Set(saved.map(\.walletId)) == ["wallet_cash_test", "wallet_bank_test"])
        #expect(vm.autoSavedItems.count == 1)
        #expect(vm.showTransactionReview == false)
    }

    // MARK: - Analytics

    @Test("A confident parse logs an auto-saved result")
    func testAnalyticsAutoSaved() async {
        let parser = MockParser()
        parser.stubbedResults = [makeParsed(confidence: 0.95)]
        let analytics = MockAnalyticsLogger()
        let vm = makeViewModel(parser: parser, analytics: analytics)
        vm.isPremium = true
        vm.language = "vi"
        vm.onAutoSave = { _ in }

        await vm.processTranscription("coffee")?.value

        let results = analytics.events(named: VoiceAnalytics.result)
        #expect(results.count == 1)
        #expect(results.first?["outcome"] as? String == "auto_saved")
        #expect(results.first?["language"] as? String == "vi")
        #expect(results.first?["item_count"] as? Int == 1)
        #expect(results.first?["parse_ms"] is Int)
        #expect(analytics.events(named: VoiceAnalytics.reviewClosed).isEmpty)
    }

    @Test("A reviewed parse logs review, then saved once with no edits")
    func testAnalyticsReviewSaved() async throws {
        let parser = MockParser()
        parser.stubbedResults = [makeParsed(confidence: 0.8)]
        let analytics = MockAnalyticsLogger()
        let vm = makeViewModel(parser: parser, analytics: analytics)
        vm.isPremium = true
        vm.defaultWalletId = "wallet_default_test"

        await vm.processTranscription("coffee")?.value
        let saved = try VoiceTransactionBuilder.transactions(from: vm.parsedTransactions, defaultWalletId: "wallet_default_test")
        vm.reviewSaved(saved)
        vm.reviewDismissed()

        #expect(analytics.events(named: VoiceAnalytics.result).first?["outcome"] as? String == "review")
        let closed = analytics.events(named: VoiceAnalytics.reviewClosed)
        #expect(closed.count == 1)
        #expect(closed.first?["action"] as? String == "saved")
        #expect(closed.first?["edited"] as? Int == 0)
    }

    @Test("Closing the review without saving logs a discard")
    func testAnalyticsReviewDiscarded() async {
        let parser = MockParser()
        parser.stubbedResults = [makeParsed(confidence: 0.7), makeParsed(confidence: 0.8)]
        let analytics = MockAnalyticsLogger()
        let vm = makeViewModel(parser: parser, analytics: analytics)
        vm.isPremium = true

        await vm.processTranscription("coffee and bread")?.value
        vm.reviewDismissed()

        let closed = analytics.events(named: VoiceAnalytics.reviewClosed)
        #expect(closed.count == 1)
        #expect(closed.first?["action"] as? String == "discarded")
        #expect(closed.first?["item_count"] as? Int == 2)
    }

    @Test("An empty parse logs a failed result")
    func testAnalyticsFailed() async {
        let analytics = MockAnalyticsLogger()
        let vm = makeViewModel(parser: MockParser(), analytics: analytics)
        vm.isPremium = true

        await vm.processTranscription("nonsense words")?.value

        #expect(analytics.events(named: VoiceAnalytics.result).first?["outcome"] as? String == "failed")
    }

    @Test("Silence logs no_speech and the limit logs limit_reached without parsing")
    func testAnalyticsNoSpeechAndLimit() async {
        let parser = MockParser()
        let analytics = MockAnalyticsLogger()
        let vm = makeViewModel(parser: parser, analytics: analytics)
        vm.isPremium = false
        for _ in 0..<AppConstants.freeTierGeminiLimit { vm.usageLimitService.incrementUsage() }

        vm.processTranscription("   ")
        vm.processTranscription("coffee")
        vm.handleRecordStart()

        let outcomes = analytics.events(named: VoiceAnalytics.result).compactMap { $0["outcome"] as? String }
        #expect(outcomes == ["no_speech", "limit_reached", "limit_reached"])
        #expect(parser.callCount == 0)
    }

    // MARK: - Voice samples

    @Test("An auto-saved parse records a sample with what was said and what was saved")
    func testSampleAutoSaved() async {
        let parser = MockParser()
        parser.stubbedResults = [makeParsed(confidence: 0.95)]
        let samples = MockVoiceSampleRecorder()
        let vm = makeViewModel(parser: parser, samples: samples)
        vm.isPremium = true
        vm.currency = "VND"
        vm.onAutoSave = { _ in }

        await vm.processTranscription("coffee fifty test")?.value

        #expect(samples.recorded.count == 1)
        let sample = samples.recorded.first
        #expect(sample?.input == "coffee fifty test")
        #expect(sample?.outcome == .autoSaved)
        #expect(sample?.action == "auto_saved")
        #expect(sample?.currency == "VND")
        #expect(sample?.parsed.count == 1)
        #expect(sample?.final?.count == 1)
    }

    @Test("A reviewed parse records one sample when saved, with the edit flag")
    func testSampleReviewSaved() async throws {
        let parser = MockParser()
        parser.stubbedResults = [makeParsed(confidence: 0.8)]
        let samples = MockVoiceSampleRecorder()
        let vm = makeViewModel(parser: parser, samples: samples)
        vm.isPremium = true
        vm.defaultWalletId = "wallet_default_test"

        await vm.processTranscription("coffee test")?.value
        #expect(samples.recorded.isEmpty)

        let saved = try VoiceTransactionBuilder.transactions(from: vm.parsedTransactions, defaultWalletId: "wallet_default_test")
        saved[0].categoryId = "shopping"
        vm.reviewSaved(saved)
        vm.reviewDismissed()

        #expect(samples.recorded.count == 1)
        #expect(samples.recorded.first?.action == "saved")
        #expect(samples.recorded.first?.edited == true)
        #expect(samples.recorded.first?.input == "coffee test")
        #expect(samples.recorded.first?.final?.first?.categoryId == "shopping")
    }

    @Test("A discarded review and a failed parse both record a sample with nothing saved")
    func testSampleDiscardedAndFailed() async {
        let parser = MockParser()
        parser.stubbedResults = [makeParsed(confidence: 0.7)]
        let samples = MockVoiceSampleRecorder()
        let vm = makeViewModel(parser: parser, samples: samples)
        vm.isPremium = true

        await vm.processTranscription("coffee test")?.value
        vm.reviewDismissed()
        parser.stubbedResults = []
        await vm.processTranscription("gibberish test")?.value

        #expect(samples.recorded.map(\.outcome) == [.review, .failed])
        #expect(samples.recorded.map(\.action) == ["discarded", nil])
        #expect(samples.recorded.allSatisfy { $0.final == nil })
        #expect(samples.recorded.last?.input == "gibberish test")
    }

    @Test("Silence records no sample")
    func testNoSampleForSilence() {
        let samples = MockVoiceSampleRecorder()
        let vm = makeViewModel(samples: samples)
        vm.processTranscription("  ")
        #expect(samples.recorded.isEmpty)
    }

    // MARK: - Review prompt

    private func makeConfidentViewModel(
        preferences: PreferencesService,
        appVersion: String = "9.9.9-test"
    ) -> VoiceCaptureViewModel {
        let parser = MockParser()
        parser.stubbedResults = [makeParsed(confidence: 0.95)]
        let vm = makeViewModel(parser: parser, preferences: preferences, appVersion: appVersion)
        vm.isPremium = true
        vm.onAutoSave = { _ in }
        return vm
    }

    @Test("The third successful voice save asks for a review")
    func testReviewRequestedAfterThreeSaves() async {
        let prefs = makePrefs()
        let vm = makeConfidentViewModel(preferences: prefs)

        await vm.processTranscription("coffee one")?.value
        await vm.processTranscription("coffee two")?.value
        #expect(vm.shouldRequestReview == false)

        await vm.processTranscription("coffee three")?.value
        #expect(vm.shouldRequestReview == true)
        #expect(prefs.voiceSaveCount == 3)
        #expect(prefs.lastReviewPromptVersion == "9.9.9-test")
    }

    @Test("Saves from the review sheet count toward the review prompt")
    func testReviewSheetSavesCount() async throws {
        let parser = MockParser()
        parser.stubbedResults = [makeParsed(confidence: 0.5)]
        let prefs = makePrefs()
        let vm = makeViewModel(parser: parser, preferences: prefs)
        vm.isPremium = true
        vm.onAutoSave = { _ in }

        for _ in 0..<3 {
            await vm.processTranscription("coffee")?.value
            let saved = try VoiceTransactionBuilder.transactions(from: vm.parsedTransactions, defaultWalletId: "wallet_default_test")
            vm.reviewSaved(saved)
        }

        #expect(prefs.voiceSaveCount == 3)
        #expect(vm.shouldRequestReview == true)
    }

    @Test("Discarded reviews and failed parses don't count toward the review prompt")
    func testFailuresDontCount() async {
        let parser = MockParser()
        let prefs = makePrefs()
        let vm = makeViewModel(parser: parser, preferences: prefs)
        vm.isPremium = true
        vm.onAutoSave = { _ in }

        parser.stubbedResults = []
        await vm.processTranscription("nothing useful")?.value
        parser.stubbedResults = [makeParsed(confidence: 0.5)]
        await vm.processTranscription("coffee")?.value
        vm.reviewDismissed()

        #expect(prefs.voiceSaveCount == 0)
        #expect(vm.shouldRequestReview == false)
    }

    @Test("The review prompt is asked once per app version")
    func testReviewRequestedOncePerVersion() async {
        let prefs = makePrefs()
        let vm = makeConfidentViewModel(preferences: prefs)
        for _ in 0..<3 { await vm.processTranscription("coffee")?.value }
        #expect(vm.shouldRequestReview == true)

        vm.shouldRequestReview = false
        await vm.processTranscription("coffee again")?.value
        #expect(vm.shouldRequestReview == false)

        let updated = makeConfidentViewModel(preferences: prefs, appVersion: "9.9.10-test")
        await updated.processTranscription("coffee after update")?.value
        #expect(updated.shouldRequestReview == true)
        #expect(prefs.lastReviewPromptVersion == "9.9.10-test")
    }
}
