import SwiftUI
import SwiftData

/// Main container with bottom tab bar and center voice FAB
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(SubscriptionViewModel.self) private var subscription
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var selectedTab = 0
    @State private var voiceService = VoiceService()
    @State private var usageLimitService = UsageLimitService()
    @State private var showVoiceOverlay = false
    @State private var parsedTransactions: [ParsedTransaction] = []
    @State private var showTransactionReview = false
    @State private var showPermissionAlert = false
    @State private var showLimitReachedAlert = false
    @State private var showPaywall = false
    @State private var isProcessingVoice = false
    // Fallback: manual entry with pre-filled transcription
    @State private var fallbackTranscription = ""
    @State private var showManualFallback = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                Tab(L10n.tr("home.title", appConfig.language), systemImage: "house.fill", value: 0) {
                    HomeView()
                }
                Tab(L10n.tr("transactions.title", appConfig.language), systemImage: "list.bullet.rectangle.fill", value: 1) {
                    TransactionsView()
                }
                Tab(L10n.tr("settings.title", appConfig.language), systemImage: "gearshape.fill", value: 2) {
                    SettingsView()
                }
            }
            .tint(AppTheme.primaryMint)

            VoiceFABButton(language: appConfig.language) {
                handleVoiceButtonTap()
            }
            .padding(.trailing, AppTheme.spacing16)
            .padding(.bottom, 90)

            // Processing indicator
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
                    .background(
                        Capsule()
                            .fill(AppTheme.primaryMint)
                    )
                    .padding(.bottom, 100)
                    .frame(maxWidth: .infinity)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: isProcessingVoice)
        .onChange(of: subscription.isPro) {
            usageLimitService.isPro = subscription.isPro
        }
        .onAppear {
            usageLimitService.isPro = subscription.isPro
        }
        .fullScreenCover(isPresented: $showVoiceOverlay) {
            VoiceOverlay(
                voiceService: voiceService,
                onComplete: { transcription in
                    showVoiceOverlay = false
                    processTranscription(transcription)
                },
                onCancel: {
                    voiceService.cancelListening()
                    showVoiceOverlay = false
                }
            )
        }
        .sheet(isPresented: $showTransactionReview) {
            EditableExpenseDialog(
                parsedExpenses: parsedTransactions,
                categories: categories,
                onSave: { transactions in
                    for transaction in transactions {
                        modelContext.insert(transaction)
                    }
                    parsedTransactions = []
                }
            )
        }
        .sheet(isPresented: $showManualFallback) {
            TransactionFormView(
                categories: categories
            ) { transaction in
                modelContext.insert(transaction)
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
            Button(L10n.tr("common.upgrade_pro", appConfig.language)) {
                showPaywall = true
            }
            Button(L10n.tr("alert.enter_manually", appConfig.language)) {
                showManualFallback = true
            }
            Button(L10n.tr("common.cancel", appConfig.language), role: .cancel) { }
        } message: {
            Text(L10n.tr("alert.daily_limit_message", appConfig.language, AppConstants.freeTierGeminiLimit))
        }
    }

    // MARK: - Voice Flow

    private func handleVoiceButtonTap() {
        // Check AI parse limit before starting voice input
        if !subscription.isPro && usageLimitService.hasReachedLimit {
            showLimitReachedAlert = true
            return
        }

        Task {
            var authorized = voiceService.isAuthorized
            if !authorized {
                authorized = await voiceService.requestPermissions()
            }
            guard authorized else {
                showPermissionAlert = true
                return
            }

            do {
                try voiceService.startListening(language: appConfig.language)
                showVoiceOverlay = true
            } catch {
                print("[MainTabView] Failed to start voice: \(error)")
            }
        }
    }

    private func processTranscription(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        guard GeminiParserService.isAvailable else {
            fallbackTranscription = text
            showManualFallback = true
            return
        }

        // Check limit before parsing
        if !subscription.isPro && usageLimitService.hasReachedLimit {
            fallbackTranscription = text
            showLimitReachedAlert = true
            return
        }

        isProcessingVoice = true
        Task {
            let results = await GeminiParserService.parse(
                input: text,
                categories: categories,
                language: appConfig.language,
                usageLimitService: usageLimitService
            )

            await MainActor.run {
                isProcessingVoice = false
                if results.isEmpty {
                    // Parsing failed or limit reached — fall back to manual entry
                    fallbackTranscription = text
                    showManualFallback = true
                } else {
                    parsedTransactions = results
                    showTransactionReview = true
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
        .environment(SubscriptionViewModel())
}
