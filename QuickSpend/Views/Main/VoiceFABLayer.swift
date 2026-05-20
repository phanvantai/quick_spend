import SwiftUI
import SwiftData

/// Voice recording FAB, recording bubble, processing indicator, toast, and related sheets/alerts.
/// Drop this into a ZStack above the TabView — it reads all dependencies from the environment.
struct VoiceFABLayer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(SubscriptionViewModel.self) private var subscription
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var voiceService = VoiceService()
    @State private var usageLimitService = UsageLimitService()
    private let preferences = PreferencesService.shared

    @State private var isRecordingActive = false
    @State private var recordingStartTask: DispatchWorkItem?
    @State private var parsedTransactions: [ParsedTransaction] = []
    @State private var showTransactionReview = false
    @State private var showPermissionAlert = false
    @State private var showLimitReachedAlert = false
    @State private var showPaywall = false
    @State private var isProcessingVoice = false
    @State private var fallbackTranscription = ""
    @State private var showManualFallback = false
    @State private var parseFailureMessage = ""
    @State private var showParseFailureToast = false
    @State private var isDragCancelling = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VoiceFABButton(
                language: appConfig.language,
                isRecording: isRecordingActive || voiceService.isListening,
                soundLevel: voiceService.soundLevel,
                transcription: voiceService.transcription,
                showTutorial: !preferences.hasShownVoiceTutorial,
                onRecordStart: { handleRecordStart() },
                onRecordEnd: { handleRecordEnd() },
                onRecordCancel: { handleRecordCancel() },
                onTutorialDismissed: { preferences.markVoiceTutorialShown() },
                onDragCancelStateChange: { isDragCancelling = $0 }
            )
            .allowsHitTesting(!isProcessingVoice)
            .opacity(isProcessingVoice ? 0.5 : 1.0)
            .padding(.trailing, AppTheme.spacing16)
            .padding(.bottom, 90)

            if isRecordingActive || voiceService.isListening {
                VStack {
                    Spacer()
                    RecordingBubbleView(
                        language: appConfig.language,
                        transcription: voiceService.transcription,
                        soundLevel: voiceService.soundLevel,
                        isDragCancelling: isDragCancelling
                    )
                    .padding(.horizontal, AppTheme.spacing16)
                    .padding(.bottom, 200)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9, anchor: .bottom).combined(with: .opacity),
                    removal: .scale(scale: 0.95, anchor: .bottom).combined(with: .opacity)
                ))
            }

            if isProcessingVoice {
                VStack {
                    Spacer()
                    HStack(spacing: AppTheme.spacing8) {
                        ProgressView()
                            .tint(.white)
                        Text(L10n.tr("common.processing", appConfig.language))
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, AppTheme.spacing16)
                    .padding(.vertical, AppTheme.spacing12)
                    .background(Capsule().fill(AppTheme.adaptiveAccent(colorScheme)))
                    .padding(.bottom, 100)
                    .frame(maxWidth: .infinity)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if showParseFailureToast {
                HStack(spacing: AppTheme.spacing8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.warning)
                    Text(parseFailureMessage)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.vertical, AppTheme.spacing12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                )
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation { showParseFailureToast = false }
                    }
                }
            }
        }
        .animation(.easeInOut, value: showParseFailureToast)
        .animation(.easeInOut, value: isProcessingVoice)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecordingActive)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: voiceService.isListening)
        .onChange(of: voiceService.isListening) { _, newValue in
            if !newValue && isRecordingActive { isRecordingActive = false }
        }
        .onChange(of: subscription.isPremium) {
            usageLimitService.isPremium = subscription.isPremium
        }
        .onAppear {
            usageLimitService.isPremium = subscription.isPremium
        }
        .sheet(isPresented: $showTransactionReview) {
            EditableExpenseDialog(
                parsedExpenses: parsedTransactions,
                categories: categories,
                onSave: { transactions in
                    for transaction in transactions { modelContext.insert(transaction) }
                    parsedTransactions = []
                }
            )
        }
        .sheet(isPresented: $showManualFallback) {
            TransactionFormView(
                categories: categories,
                initialNote: fallbackTranscription.isEmpty ? nil : fallbackTranscription
            ) { transaction in
                modelContext.insert(transaction)
                fallbackTranscription = ""
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert(
            L10n.tr("alert.mic_required", appConfig.language),
            isPresented: $showPermissionAlert
        ) {
            Button(L10n.tr("alert.open_settings", appConfig.language)) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(L10n.tr("common.cancel", appConfig.language), role: .cancel) { }
        } message: {
            Text(L10n.tr("alert.mic_message", appConfig.language))
        }
        .alert(
            L10n.tr("alert.daily_limit", appConfig.language),
            isPresented: $showLimitReachedAlert
        ) {
            Button(L10n.tr("common.upgrade_premium", appConfig.language)) { showPaywall = true }
            Button(L10n.tr("alert.enter_manually", appConfig.language)) { showManualFallback = true }
            Button(L10n.tr("common.cancel", appConfig.language), role: .cancel) { }
        } message: {
            Text(L10n.tr("alert.daily_limit_message", appConfig.language, AppConstants.freeTierGeminiLimit))
        }
    }

    // MARK: - Hold-to-Record Voice Flow

    private func handleRecordStart() {
        guard !isProcessingVoice, !isRecordingActive else { return }

        if !subscription.isPremium && usageLimitService.hasReachedLimit {
            showLimitReachedAlert = true
            return
        }

        guard voiceService.isAuthorized else {
            Task {
                let authorized = await voiceService.requestPermissions()
                if !authorized { showPermissionAlert = true }
            }
            return
        }

        let workItem = DispatchWorkItem { [self] in
            do {
                try voiceService.startListening(language: appConfig.speechLanguage)
                isRecordingActive = true
            } catch {
                print("[VoiceFABLayer] Failed to start voice: \(error)")
            }
        }
        recordingStartTask = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + AppConstants.holdToRecordMinDuration,
            execute: workItem
        )
    }

    private func handleRecordEnd() {
        recordingStartTask?.cancel()
        recordingStartTask = nil
        guard isRecordingActive else { return }
        isRecordingActive = false
        let text = voiceService.stopListening()
        print("[Voice] Recording ended — transcription: \"\(text)\" (length: \(text.count))")
        processTranscription(text)
    }

    private func handleRecordCancel() {
        recordingStartTask?.cancel()
        recordingStartTask = nil
        guard isRecordingActive else { return }
        isRecordingActive = false
        voiceService.cancelListening()
        print("[Voice] Recording cancelled by user")
    }

    private func processTranscription(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("[Voice] Transcription empty, skipping")
            return
        }

        let inputText: String
        if trimmed.count > AppConstants.maxVoiceInputLength {
            inputText = String(trimmed.prefix(AppConstants.maxVoiceInputLength))
            print("[Voice] Transcription truncated from \(trimmed.count) to \(AppConstants.maxVoiceInputLength) chars")
        } else {
            inputText = trimmed
        }

        guard GeminiParserService.isAvailable else {
            print("[Voice] Gemini not available, falling back to manual entry")
            fallbackTranscription = inputText
            showManualFallback = true
            return
        }

        if !subscription.isPremium && usageLimitService.hasReachedLimit {
            print("[Voice] Daily parse limit reached, falling back to manual entry")
            fallbackTranscription = inputText
            showLimitReachedAlert = true
            return
        }

        guard !isProcessingVoice else {
            print("[Voice] Already processing, ignoring")
            return
        }

        print("[Voice] Sending to Gemini parser: \"\(inputText)\"")
        isProcessingVoice = true
        Task {
            let results = await GeminiParserService.parse(
                input: inputText,
                categories: categories,
                language: appConfig.speechLanguage,
                currency: appConfig.config.currency,
                usageLimitService: usageLimitService
            )

            await MainActor.run {
                isProcessingVoice = false
                if results.isEmpty {
                    print("[Voice] Gemini returned no results for: \"\(inputText)\" — falling back to manual entry")
                    parseFailureMessage = L10n.tr("voice.parse_failed", appConfig.language)
                    withAnimation { showParseFailureToast = true }
                    fallbackTranscription = inputText
                    showManualFallback = true
                } else {
                    print("[Voice] Gemini parsed \(results.count) transaction(s):")
                    for (i, r) in results.enumerated() {
                        print("  [\(i+1)] \(r.type) \(r.amount) \"\(r.note)\" cat=\(r.categoryId) conf=\(String(format: "%.2f", r.confidence))")
                    }
                    var resultsWithRawInput = results
                    for i in resultsWithRawInput.indices { resultsWithRawInput[i].rawInput = inputText }
                    parsedTransactions = resultsWithRawInput
                    showTransactionReview = true
                }
            }
        }
    }
}
