import SwiftUI
import SwiftData

/// Hosts the voice-capture FAB, recording bubble, processing indicator, toast,
/// and the sheets/alerts the flow can present. Drop into a ZStack above
/// the TabView; all logic lives in `VoiceCaptureViewModel`.
///
/// This view's only job is presentation — wiring environment values into the
/// view model and forwarding callbacks to it. Recording state, parse flow,
/// limit gating, and result handling all live in the view model so they're
/// testable in isolation.
struct VoiceFABLayer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(SubscriptionViewModel.self) private var subscription
    @Environment(BalanceService.self) private var balance
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]

    @State private var vm = VoiceCaptureViewModel()
    private let preferences = PreferencesService.shared

    private var activeWallets: [Wallet] {
        WalletService.activeWallets(from: wallets)
    }

    private var defaultWalletId: String {
        WalletService.resolvedDefaultWalletId(wallets: wallets)
    }

    var body: some View {
        @Bindable var vm = vm
        ZStack(alignment: .bottomTrailing) {
            VoiceFABButton(
                language: appConfig.language,
                isRecording: vm.isRecordingOrListening,
                soundLevel: vm.voiceService.soundLevel,
                transcription: vm.voiceService.transcription,
                showTutorial: !preferences.hasShownVoiceTutorial,
                onRecordStart: { vm.handleRecordStart() },
                onRecordEnd: { vm.handleRecordEnd() },
                onRecordCancel: { vm.handleRecordCancel() },
                onTutorialDismissed: { preferences.markVoiceTutorialShown() },
                onDragCancelStateChange: { vm.isDragCancelling = $0 }
            )
            .allowsHitTesting(!vm.isBlocked)
            .opacity(vm.isBlocked ? 0.5 : 1.0)
            .padding(.trailing, AppTheme.spacing16)
            .padding(.bottom, 90)

            if vm.isRecordingOrListening {
                VStack {
                    Spacer()
                    RecordingBubbleView(
                        language: appConfig.language,
                        transcription: vm.voiceService.transcription,
                        soundLevel: vm.voiceService.soundLevel,
                        isDragCancelling: vm.isDragCancelling
                    )
                    .padding(.horizontal, AppTheme.spacing16)
                    .padding(.bottom, 200)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9, anchor: .bottom).combined(with: .opacity),
                    removal: .scale(scale: 0.95, anchor: .bottom).combined(with: .opacity)
                ))
            }

            if vm.isProcessingVoice {
                VStack {
                    Spacer()
                    HStack(spacing: AppTheme.spacing8) {
                        ProgressView()
                            .tint(.white)
                        Text(L10n.tr("common.processing", appConfig.language))
                            .font(Typography.body)
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
            if vm.showParseFailureToast {
                HStack(spacing: AppTheme.spacing8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.warning)
                    Text(vm.parseFailureMessage)
                        .font(Typography.body)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.vertical, AppTheme.spacing12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .fill(.ultraThinMaterial)
                        .shadow(.card)
                )
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation { vm.showParseFailureToast = false }
                    }
                }
            }
        }
        .animation(.easeQuick, value: vm.showParseFailureToast)
        .animation(.easeQuick, value: vm.isProcessingVoice)
        .animation(.springFast, value: vm.isRecordingActive)
        .animation(.springFast, value: vm.voiceService.isListening)
        .onAppear {
            syncToViewModel()
        }
        .onChange(of: vm.voiceService.isListening) {
            vm.syncWithVoiceServiceListeningState()
        }
        .onChange(of: subscription.isPremium) {
            vm.isPremium = subscription.isPremium
        }
        .onChange(of: appConfig.language) { vm.language = appConfig.language }
        .onChange(of: appConfig.currency) { vm.currency = appConfig.currency }
        .onChange(of: categories) { _, newCategories in vm.categories = newCategories }
        .sheet(isPresented: $vm.showTransactionReview) {
            EditableExpenseDialog(
                parsedExpenses: vm.parsedTransactions,
                categories: categories,
                wallets: activeWallets,
                defaultWalletId: defaultWalletId,
                onSave: { transactions in
                    for transaction in transactions {
                        modelContext.insert(transaction)
                        balance.applyOptimisticInsert(transaction)
                    }
                    vm.parsedTransactions = []
                }
            )
        }
        .sheet(isPresented: $vm.showManualFallback) {
            TransactionFormView(
                categories: categories,
                wallets: activeWallets,
                defaultWalletId: defaultWalletId,
                initialNote: vm.fallbackTranscription.isEmpty ? nil : vm.fallbackTranscription
            ) { transaction in
                modelContext.insert(transaction)
                balance.applyOptimisticInsert(transaction)
                vm.fallbackTranscription = ""
            }
        }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView()
        }
        .alert(
            L10n.tr("alert.mic_required", appConfig.language),
            isPresented: $vm.showPermissionAlert
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
            isPresented: $vm.showLimitReachedAlert
        ) {
            Button(L10n.tr("common.upgrade_premium", appConfig.language)) { vm.showPaywall = true }
            Button(L10n.tr("alert.enter_manually", appConfig.language)) { vm.showManualFallback = true }
            Button(L10n.tr("common.cancel", appConfig.language), role: .cancel) { }
        } message: {
            Text(L10n.tr("alert.daily_limit_message", appConfig.language, AppConstants.freeTierGeminiLimit))
        }
    }

    /// Push the current view-level inputs into the view model. Called once
    /// on first appear; later updates go through individual .onChange handlers.
    private func syncToViewModel() {
        vm.language = appConfig.language
        vm.currency = appConfig.currency
        vm.categories = categories
        vm.isPremium = subscription.isPremium
    }
}
