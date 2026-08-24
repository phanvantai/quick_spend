import SwiftUI
import SwiftData

/// One-time full-screen modal introducing the Account Balance feature to users
/// upgrading from v2.4. Fresh installs never see this — `completeOnboarding()`
/// flips `hasSeenBalanceWhatsNew = true` atomically with `isOnboardingComplete`.
///
/// Two paths:
/// - "Set up balance now" → opens wallet management, where balance lives in edit
/// - "Set up later"       → dismisses + marks seen
///
/// Custom hero: a non-interactive BalanceHero preview so the user sees exactly
/// what they'll get on Home. ModalTemplate handles the rest of the chrome.
struct WhatsNewBalanceModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig

    @State private var showWallets = false

    /// Culturally-plausible preview balance per locale so the hero looks like
    /// a real account, not a demo placeholder.
    private var previewBalance: Double {
        switch appConfig.config.currency {
        case "VND": return 12_500_000
        case "JPY": return 125_000
        case "EUR": return 2_345.67
        default:    return 2_345.67
        }
    }

    var body: some View {
        ModalTemplate(
            title: L10n.tr("balance.whatsnew_title", appConfig.language),
            subtitle: L10n.tr("balance.whatsnew_subtitle", appConfig.language),
            primary: ModalCTA(
                label: L10n.tr("balance.whatsnew_setup_cta", appConfig.language),
                icon: "arrow.right.circle.fill",
                action: { showWallets = true }
            ),
            secondary: ModalCTA(
                label: L10n.tr("balance.whatsnew_later_cta", appConfig.language),
                action: dismissAndMarkSeen
            ),
            hero: { hero },
            content: { benefits }
        )
        .sheet(isPresented: $showWallets, onDismiss: {
            // Mark-seen runs only after wallet management closes. The user made
            // an intentional choice whether or not they actually saved.
            dismissAndMarkSeen()
        }) {
            WalletManagementView()
        }
    }

    private var hero: some View {
        ZStack {
            RadialGradient(
                colors: [
                    AppTheme.primaryGreen.opacity(colorScheme == .dark ? 0.35 : 0.22),
                    AppTheme.primaryLight.opacity(0.0)
                ],
                center: .center,
                startRadius: 20,
                endRadius: 200
            )
            .frame(height: 260)
            .blur(radius: 28)

            BalanceHero(
                currentBalance: previewBalance,
                monthlyNet: nil,
                language: appConfig.language,
                currency: appConfig.config.currency,
                onTap: {}
            )
            .allowsHitTesting(false)
            .padding(.horizontal, AppTheme.spacing24)
            .shadow(
                color: AppTheme.primaryGreen.opacity(colorScheme == .dark ? 0.25 : 0.15),
                radius: 18,
                y: 6
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.tr("balance.whatsnew_title", appConfig.language))
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            benefitRow(key: "balance.whatsnew_benefit_1")
            benefitRow(key: "balance.whatsnew_benefit_2")
            benefitRow(key: "balance.whatsnew_benefit_3")
        }
        .padding(.horizontal, AppTheme.spacing24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefitRow(key: String) -> some View {
        HStack(alignment: .top, spacing: AppTheme.spacing12) {
            Image(systemName: "checkmark.circle.fill")
                .font(Typography.bodyEmphasized)
                .foregroundStyle(AppTheme.primaryGreen)
                .frame(width: 22, height: 22)
                .padding(.top, 1)

            Text(L10n.tr(key, appConfig.language))
                .font(Typography.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dismissAndMarkSeen() {
        appConfig.markBalanceWhatsNewSeen()
        dismiss()
    }
}

#Preview("Vietnamese") {
    let container = try! ModelContainer(
        for: Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self, Wallet.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    let viewModel = AppConfigViewModel()
    viewModel.setLanguage("vi")
    viewModel.setCurrency("VND")
    return WhatsNewBalanceModal()
        .modelContainer(container)
        .environment(viewModel)
        .environment(BalanceService(modelContext: container.mainContext, autoObserve: false))
}

#Preview("English Dark") {
    let container = try! ModelContainer(
        for: Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self, Wallet.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    return WhatsNewBalanceModal()
        .modelContainer(container)
        .environment(AppConfigViewModel())
        .environment(BalanceService(modelContext: container.mainContext, autoObserve: false))
        .preferredColorScheme(.dark)
}
