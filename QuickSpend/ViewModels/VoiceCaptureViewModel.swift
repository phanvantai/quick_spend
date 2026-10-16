import Foundation
import SwiftUI

/// Owns the voice-FAB capture flow's mutable state and orchestration logic.
///
/// Before v3.0 this lived inline in [Views/Main/VoiceFABLayer.swift] as 12+
/// `@State` flags plus three handlers and `processTranscription` — a god
/// view that mixed UI with the recording state machine and Gemini parse
/// pipeline. Splitting it out makes the View a thin shell and the recording
/// logic testable by injecting `ExpenseParsing`.
///
/// The view is expected to keep `language`, `currency`, `categories`, and
/// `isPremium` in sync with the environment via `.onChange` modifiers — the
/// view model deliberately does NOT read from `@Environment`, so it stays
/// independent of SwiftUI plumbing and easy to instantiate in tests.
@Observable
@MainActor
final class VoiceCaptureViewModel {

    // MARK: - Owned services

    let voiceService: VoiceService
    let usageLimitService: UsageLimitService
    private let preferences: PreferencesService
    private let parser: ExpenseParsing
    private let analytics: VoiceAnalytics
    private let samples: VoiceSampleRecording

    // MARK: - Synced from view

    /// User's selected app language. Drives speech locale + parser language hint.
    var language: String = "en"
    /// User's selected currency. Forwarded to the parser so amounts decode correctly.
    var currency: String = "USD"
    /// Latest category list from the SwiftData query — passed to the parser.
    var categories: [Category] = []
    /// Premium status mirror; flips `usageLimitService.isPremium` whenever it changes.
    var isPremium: Bool = false {
        didSet { usageLimitService.isPremium = isPremium }
    }

    // MARK: - Recording state

    /// True while the user is holding the FAB AND voice recognition has started.
    /// Goes false either when the user releases the FAB or when voiceService
    /// stops on its own (timeout/error).
    var isRecordingActive = false
    /// True when the user is dragging the FAB toward the cancel zone.
    var isDragCancelling = false
    /// Recording started from a widget or Control Center: no finger is on the
    /// FAB, so the user ends it with Done / Cancel instead of releasing.
    var isHandsFree = false
    /// Deferred start of the recognizer — gives a brief hold window so accidental
    /// taps don't trigger a recording.
    private var recordingStartTask: DispatchWorkItem?

    // MARK: - Processing state

    /// True while the parser is running. The FAB is dimmed + non-interactive while set.
    var isProcessingVoice = false

    // MARK: - Results

    /// Parsed transactions returned by the parser. Populated when the user
    /// confirms a successful capture; shown via `showTransactionReview`.
    var parsedTransactions: [ParsedTransaction] = []
    /// The raw transcription the parser couldn't make sense of — pre-fills
    /// the manual fallback form so the user doesn't retype.
    var fallbackTranscription = ""
    /// One-line message rendered in the parse-failure toast.
    var parseFailureMessage = ""

    // MARK: - Presentation flags

    var showTransactionReview = false
    var showPermissionAlert = false
    var showLimitReachedAlert = false
    var showPaywall = false
    var showManualFallback = false
    var showParseFailureToast = false
    /// Shown briefly after a confident parse was saved without review.
    var showAutoSavedToast = false
    /// What the last auto-save stored (as parsed, so a transfer is one item), for the toast.
    var autoSavedItems: [ParsedTransaction] = []

    // MARK: - Auto-save

    /// Wallet that confident parses are saved to (the app's default wallet).
    var defaultWalletId: String = Wallet.personalID
    /// Active wallets, so the parser can recognize named wallets and transfers.
    var wallets: [Wallet] = []
    /// Persists transactions from a confident parse. Set by the view, which owns
    /// the model context; when nil, every parse goes through review.
    var onAutoSave: (([Transaction]) throws -> Void)?

    // MARK: - Analytics

    /// How the current (or last) recording was started.
    private var recordingSource: VoiceAnalytics.Source = .hold
    private var recordingStartedAt: Date?
    /// Recording length of the capture being parsed, for the result event.
    private var pendingRecordSeconds: Int?
    /// What the open review sheet was showing, so its outcome can be logged
    /// once: saved (with or without edits) or discarded.
    private var reviewedItems: [ParsedTransaction]?
    /// What the user said for the open review, for the voice sample.
    private var reviewedInput = ""

    // MARK: - Init

    /// Production initializer — owns its services. Use the
    /// `voiceService:usageLimitService:preferences:parser:` overload from
    /// tests to inject mocks. The default expressions can't sit in the
    /// parameter list because they would need to evaluate outside MainActor.
    convenience init() {
        self.init(
            voiceService: VoiceService(),
            usageLimitService: UsageLimitService(),
            preferences: .shared,
            parser: GeminiExpenseParser()
        )
    }

    init(
        voiceService: VoiceService,
        usageLimitService: UsageLimitService,
        preferences: PreferencesService,
        parser: ExpenseParsing,
        analytics: AnalyticsLogging = FirebaseAnalyticsLogger(),
        samples: VoiceSampleRecording? = nil
    ) {
        self.voiceService = voiceService
        self.usageLimitService = usageLimitService
        self.preferences = preferences
        self.parser = parser
        self.analytics = VoiceAnalytics(logger: analytics)
        self.samples = samples ?? VoiceSampleRecorder.shared
    }

    // MARK: - Derived

    /// FAB should be visually + interactively blocked while processing.
    var isBlocked: Bool { isProcessingVoice }

    /// The view shows the recording bubble + processing indicator whenever
    /// either the FAB-driven flag or the service's own listening flag is true.
    var isRecordingOrListening: Bool { isRecordingActive || voiceService.isListening }

    // MARK: - Recording handlers

    /// Hold-to-record start handler. Gates on premium-limit and microphone/
    /// speech auth before scheduling the actual `startListening` call.
    func handleRecordStart() {
        guard !isProcessingVoice, !isRecordingActive else { return }

        if !isPremium && usageLimitService.hasReachedLimit {
            analytics.logResult(source: .hold, outcome: .limitReached, language: language)
            showLimitReachedAlert = true
            return
        }

        guard voiceService.isAuthorized else {
            Task { [weak self] in
                guard let self else { return }
                let authorized = await self.voiceService.requestPermissions()
                if !authorized { self.showPermissionAlert = true }
            }
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            do {
                try self.voiceService.startListening(language: self.language)
                self.isRecordingActive = true
                self.recordingDidStart(source: .hold)
            } catch {
                print("[VoiceCaptureViewModel] Failed to start voice: \(error)")
            }
        }
        recordingStartTask = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + AppConstants.holdToRecordMinDuration,
            execute: workItem
        )
    }

    /// Starts recording right away for a widget / Control Center launch.
    /// Same gates as hold-to-record; asks for permission and then starts.
    func startHandsFreeRecording() {
        guard !isProcessingVoice, !isRecordingActive else { return }

        if !isPremium && usageLimitService.hasReachedLimit {
            analytics.logResult(source: .widget, outcome: .limitReached, language: language)
            showLimitReachedAlert = true
            return
        }

        guard voiceService.isAuthorized else {
            Task { [weak self] in
                guard let self else { return }
                if await self.voiceService.requestPermissions() {
                    self.startHandsFreeRecording()
                } else {
                    self.showPermissionAlert = true
                }
            }
            return
        }

        do {
            try voiceService.startListening(language: language)
            isRecordingActive = voiceService.isListening
            isHandsFree = isRecordingActive
            if isRecordingActive { recordingDidStart(source: .widget) }
        } catch {
            print("[VoiceCaptureViewModel] Failed to start hands-free voice: \(error)")
        }
    }

    func finishHandsFreeRecording() {
        isHandsFree = false
        handleRecordEnd()
    }

    func cancelHandsFreeRecording() {
        isHandsFree = false
        handleRecordCancel()
    }

    /// Hold-to-record end handler. Stops voice and kicks off parsing.
    func handleRecordEnd() {
        isHandsFree = false
        recordingStartTask?.cancel()
        recordingStartTask = nil
        guard isRecordingActive else { return }
        isRecordingActive = false
        let text = voiceService.stopListening()
        print("[VoiceCapture] Recording ended — transcription: \"\(text)\" (length: \(text.count))")
        pendingRecordSeconds = recordSecondsSoFar()
        processTranscription(text)
    }

    /// Drag-to-cancel handler. Stops voice without parsing.
    func handleRecordCancel() {
        isHandsFree = false
        recordingStartTask?.cancel()
        recordingStartTask = nil
        guard isRecordingActive else { return }
        isRecordingActive = false
        voiceService.cancelListening()
        print("[VoiceCapture] Recording cancelled by user")
        analytics.logCancelled(source: recordingSource, language: language, recordSeconds: recordSecondsSoFar() ?? 0)
        recordingStartedAt = nil
    }

    private func recordingDidStart(source: VoiceAnalytics.Source) {
        recordingSource = source
        recordingStartedAt = .now
        analytics.logStarted(source: source, language: language)
    }

    private func recordSecondsSoFar() -> Int? {
        recordingStartedAt.map { Int(Date.now.timeIntervalSince($0).rounded()) }
    }

    /// Reconciles the FAB-driven `isRecordingActive` flag with the underlying
    /// service's own listening state. If the service stops on its own
    /// (timeout, error, OS interruption), we clear the FAB state too.
    func syncWithVoiceServiceListeningState() {
        guard !voiceService.isListening && isRecordingActive else { return }
        if isHandsFree {
            // Nobody is holding the FAB, so parse what was heard.
            finishHandsFreeRecording()
        } else {
            isRecordingActive = false
        }
    }

    // MARK: - Parsing

    /// Sends a transcription through the parser. Public so tests can exercise
    /// it directly without going through the recording state machine. Returns
    /// after the async parse completes, so callers in tests can `await` it.
    @discardableResult
    func processTranscription(_ text: String) -> Task<Void, Never>? {
        let recordSeconds = pendingRecordSeconds
        pendingRecordSeconds = nil
        recordingStartedAt = nil
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("[VoiceCapture] Transcription empty, skipping")
            logResult(.noSpeech, recordSeconds: recordSeconds)
            return nil
        }

        let inputText: String
        if trimmed.count > AppConstants.maxVoiceInputLength {
            inputText = String(trimmed.prefix(AppConstants.maxVoiceInputLength))
            print("[VoiceCapture] Transcription truncated from \(trimmed.count) to \(AppConstants.maxVoiceInputLength) chars")
        } else {
            inputText = trimmed
        }

        guard GeminiParserService.isAvailable else {
            print("[VoiceCapture] Gemini not available, falling back to manual entry")
            fallbackTranscription = inputText
            showManualFallback = true
            logResult(.unavailable, recordSeconds: recordSeconds)
            return nil
        }

        if !isPremium && usageLimitService.hasReachedLimit {
            print("[VoiceCapture] Daily parse limit reached, falling back to manual entry")
            fallbackTranscription = inputText
            showLimitReachedAlert = true
            logResult(.limitReached, recordSeconds: recordSeconds)
            return nil
        }

        guard !isProcessingVoice else {
            print("[VoiceCapture] Already processing, ignoring")
            return nil
        }

        print("[VoiceCapture] Sending to parser: \"\(inputText)\"")
        isProcessingVoice = true

        let parseStartedAt = Date.now
        return Task { [weak self] in
            guard let self else { return }
            let results = await self.parser.parse(
                input: inputText,
                categories: self.categories,
                language: self.language,
                wallets: self.wallets,
                defaultWalletId: self.defaultWalletId,
                currency: self.currency,
                usageLimitService: self.usageLimitService
            )
            let parseMs = Int(Date.now.timeIntervalSince(parseStartedAt) * 1000)
            self.handleParseResults(results, inputText: inputText, recordSeconds: recordSeconds, parseMs: parseMs)
        }
    }

    private func handleParseResults(_ results: [ParsedTransaction], inputText: String, recordSeconds: Int?, parseMs: Int) {
        isProcessingVoice = false
        if results.isEmpty {
            logResult(.failed, recordSeconds: recordSeconds, parseMs: parseMs)
            recordSample(input: inputText, outcome: .failed)
            print("[VoiceCapture] Parser returned no results for: \"\(inputText)\" — falling back to manual entry")
            parseFailureMessage = L10n.tr("voice.parse_failed", language)
            withAnimation { showParseFailureToast = true }
            fallbackTranscription = inputText
            showManualFallback = true
        } else {
            print("[VoiceCapture] Parser produced \(results.count) transaction(s)")
            var resultsWithRawInput = results
            for i in resultsWithRawInput.indices { resultsWithRawInput[i].rawInput = inputText }
            if let saved = autoSaveIfConfident(resultsWithRawInput) {
                logResult(.autoSaved, items: resultsWithRawInput, recordSeconds: recordSeconds, parseMs: parseMs)
                recordSample(input: inputText, outcome: .autoSaved, action: "auto_saved", parsed: resultsWithRawInput, saved: saved)
                return
            }
            logResult(.review, items: resultsWithRawInput, recordSeconds: recordSeconds, parseMs: parseMs)
            parsedTransactions = resultsWithRawInput
            reviewedItems = resultsWithRawInput
            reviewedInput = inputText
            showTransactionReview = true
        }
    }

    private func logResult(
        _ outcome: VoiceAnalytics.Outcome,
        items: [ParsedTransaction] = [],
        recordSeconds: Int?,
        parseMs: Int? = nil
    ) {
        analytics.logResult(
            source: recordingSource,
            outcome: outcome,
            items: items,
            language: language,
            recordSeconds: recordSeconds,
            parseMs: parseMs
        )
    }

    // MARK: - Review outcome

    /// Call after the review sheet saved `transactions`.
    func reviewSaved(_ transactions: [Transaction]) {
        guard let items = reviewedItems else { return }
        reviewedItems = nil
        let edited = VoiceAnalytics.wasEdited(parsed: items, saved: transactions, defaultWalletId: defaultWalletId)
        analytics.logReviewClosed(source: recordingSource, saved: true, edited: edited, itemCount: transactions.count)
        recordSample(input: reviewedInput, outcome: .review, action: "saved", edited: edited, parsed: items, saved: transactions)
    }

    /// Call when the review sheet closes; logs a discard unless it was saved.
    func reviewDismissed() {
        guard let items = reviewedItems else { return }
        reviewedItems = nil
        analytics.logReviewClosed(source: recordingSource, saved: false, edited: false, itemCount: items.count)
        recordSample(input: reviewedInput, outcome: .review, action: "discarded", parsed: items)
    }

    private func recordSample(
        input: String,
        outcome: VoiceAnalytics.Outcome,
        action: String? = nil,
        edited: Bool = false,
        parsed: [ParsedTransaction] = [],
        saved: [Transaction]? = nil
    ) {
        samples.record(VoiceSample(
            input: input,
            source: recordingSource,
            outcome: outcome,
            action: action,
            edited: edited,
            language: language,
            currency: currency,
            parsed: parsed,
            saved: saved,
            names: VoiceSample.Names(categories: categories, wallets: wallets)
        ))
    }

    /// Same rule as Siri: when every item is confident, save straight to the
    /// default wallet and show a short toast instead of the review sheet.
    /// Returns the saved rows, or nil (so the caller shows review) when not
    /// confident or the save failed.
    private func autoSaveIfConfident(_ parsed: [ParsedTransaction]) -> [Transaction]? {
        guard let onAutoSave, VoiceAutoSavePolicy.shouldAutoSave(parsed) else { return nil }
        let transactions: [Transaction]
        do {
            transactions = try VoiceTransactionBuilder.transactions(from: parsed, defaultWalletId: defaultWalletId)
            try onAutoSave(transactions)
        } catch {
            print("[VoiceCapture] Auto-save failed, showing review instead: \(error)")
            return nil
        }
        autoSavedItems = parsed
        showAutoSavedToast = true
        return transactions
    }
}
