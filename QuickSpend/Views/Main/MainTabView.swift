import SwiftUI
import SwiftData

/// Main container with bottom tab bar and center voice FAB
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Query(sort: \QuickCategory.name) private var categories: [QuickCategory]

    @State private var selectedTab = 0
    @State private var voiceService = VoiceService()
    @State private var usageLimitService = UsageLimitService()
    @State private var showVoiceOverlay = false
    @State private var parsedExpenses: [ParsedExpense] = []
    @State private var showExpenseReview = false
    @State private var showPermissionAlert = false
    @State private var isProcessingVoice = false
    // Fallback: manual entry with pre-filled transcription
    @State private var fallbackTranscription = ""
    @State private var showManualFallback = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Tab("Home", systemImage: "house.fill", value: 0) {
                    HomeView()
                }
                Tab("Transactions", systemImage: "calendar", value: 1) {
                    TransactionsView()
                }
                Tab("Settings", systemImage: "gearshape.fill", value: 2) {
                    SettingsView()
                }
            }
            .tint(AppTheme.primaryMint)

            VoiceFABButton {
                handleVoiceButtonTap()
            }

            // Processing indicator
            if isProcessingVoice {
                VStack {
                    Spacer()
                    HStack(spacing: AppTheme.spacing8) {
                        ProgressView()
                            .tint(.white)
                        Text("Processing...")
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
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: isProcessingVoice)
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
        .sheet(isPresented: $showExpenseReview) {
            EditableExpenseDialog(
                parsedExpenses: parsedExpenses,
                categories: categories,
                onSave: { expenses in
                    for expense in expenses {
                        modelContext.insert(expense)
                    }
                    parsedExpenses = []
                }
            )
        }
        .sheet(isPresented: $showManualFallback) {
            ExpenseFormView(
                categories: categories
            ) { expense in
                modelContext.insert(expense)
            }
        }
        .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please grant microphone and speech recognition access in Settings to use voice input.")
        }
    }

    // MARK: - Voice Flow

    private func handleVoiceButtonTap() {
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
                    parsedExpenses = results
                    showExpenseReview = true
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Expense.self, QuickCategory.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
        .environment(SubscriptionViewModel())
}
