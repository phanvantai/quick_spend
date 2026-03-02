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

    private var isVi: Bool { appConfig.language == "vi" }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Tab("Home", systemImage: "house.fill", value: 0) {
                    HomeView()
                }
                Tab("Settings", systemImage: "gearshape.fill", value: 1) {
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
                        Text(isVi ? "Đang xử lý..." : "Processing...")
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
            ExpenseFormView(
                categories: categories
            ) { transaction in
                modelContext.insert(transaction)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert(
            isVi ? "Cần quyền truy cập micro" : "Microphone Access Required",
            isPresented: $showPermissionAlert
        ) {
            Button(isVi ? "Mở Cài đặt" : "Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(isVi ? "Hủy" : "Cancel", role: .cancel) { }
        } message: {
            Text(isVi
                 ? "Vui lòng cấp quyền micro và nhận dạng giọng nói trong Cài đặt để sử dụng nhập liệu bằng giọng nói."
                 : "Please grant microphone and speech recognition access in Settings to use voice input.")
        }
        .alert(
            isVi ? "Đã hết lượt phân tích" : "Daily Limit Reached",
            isPresented: $showLimitReachedAlert
        ) {
            Button(isVi ? "Nâng cấp Pro" : "Upgrade to Pro") {
                showPaywall = true
            }
            Button(isVi ? "Nhập thủ công" : "Enter Manually") {
                showManualFallback = true
            }
            Button(isVi ? "Hủy" : "Cancel", role: .cancel) { }
        } message: {
            Text(isVi
                 ? "Bạn đã sử dụng hết \(AppConstants.freeTierGeminiLimit) lượt phân tích AI miễn phí hôm nay. Nâng cấp Pro để không giới hạn."
                 : "You've used all \(AppConstants.freeTierGeminiLimit) free AI parses for today. Upgrade to Pro for unlimited.")
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
