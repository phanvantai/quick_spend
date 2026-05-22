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
        parser: ExpenseParsing
    ) {
        self.voiceService = voiceService
        self.usageLimitService = usageLimitService
        self.preferences = preferences
        self.parser = parser
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

    /// Hold-to-record end handler. Stops voice and kicks off parsing.
    func handleRecordEnd() {
        recordingStartTask?.cancel()
        recordingStartTask = nil
        guard isRecordingActive else { return }
        isRecordingActive = false
        let text = voiceService.stopListening()
        print("[VoiceCapture] Recording ended — transcription: \"\(text)\" (length: \(text.count))")
        processTranscription(text)
    }

    /// Drag-to-cancel handler. Stops voice without parsing.
    func handleRecordCancel() {
        recordingStartTask?.cancel()
        recordingStartTask = nil
        guard isRecordingActive else { return }
        isRecordingActive = false
        voiceService.cancelListening()
        print("[VoiceCapture] Recording cancelled by user")
    }

    /// Reconciles the FAB-driven `isRecordingActive` flag with the underlying
    /// service's own listening state. If the service stops on its own
    /// (timeout, error, OS interruption), we clear the FAB state too.
    func syncWithVoiceServiceListeningState() {
        if !voiceService.isListening && isRecordingActive {
            isRecordingActive = false
        }
    }

    // MARK: - Parsing

    /// Sends a transcription through the parser. Public so tests can exercise
    /// it directly without going through the recording state machine. Returns
    /// after the async parse completes, so callers in tests can `await` it.
    @discardableResult
    func processTranscription(_ text: String) -> Task<Void, Never>? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("[VoiceCapture] Transcription empty, skipping")
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
            return nil
        }

        if !isPremium && usageLimitService.hasReachedLimit {
            print("[VoiceCapture] Daily parse limit reached, falling back to manual entry")
            fallbackTranscription = inputText
            showLimitReachedAlert = true
            return nil
        }

        guard !isProcessingVoice else {
            print("[VoiceCapture] Already processing, ignoring")
            return nil
        }

        print("[VoiceCapture] Sending to parser: \"\(inputText)\"")
        isProcessingVoice = true

        return Task { [weak self] in
            guard let self else { return }
            let results = await self.parser.parse(
                input: inputText,
                categories: self.categories,
                language: self.language,
                currency: self.currency,
                usageLimitService: self.usageLimitService
            )
            self.handleParseResults(results, inputText: inputText)
        }
    }

    private func handleParseResults(_ results: [ParsedTransaction], inputText: String) {
        isProcessingVoice = false
        if results.isEmpty {
            print("[VoiceCapture] Parser returned no results for: \"\(inputText)\" — falling back to manual entry")
            parseFailureMessage = L10n.tr("voice.parse_failed", language)
            withAnimation { showParseFailureToast = true }
            fallbackTranscription = inputText
            showManualFallback = true
        } else {
            print("[VoiceCapture] Parser produced \(results.count) transaction(s)")
            var resultsWithRawInput = results
            for i in resultsWithRawInput.indices { resultsWithRawInput[i].rawInput = inputText }
            parsedTransactions = resultsWithRawInput
            showTransactionReview = true
        }
    }
}
