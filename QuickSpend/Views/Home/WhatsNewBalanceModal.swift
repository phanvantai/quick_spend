import SwiftUI
import SwiftData

/// One-time full-screen modal introducing the Account Balance feature to users
/// upgrading from v2.4. Fresh installs never see this — `completeOnboarding()`
/// flips `hasSeenBalanceWhatsNew = true` atomically with `isOnboardingComplete`.
///
/// Two paths:
/// - "Set up balance now" → opens BalanceEditSheet, then dismisses + marks seen
/// - "Set up later"       → dismisses + marks seen
///
/// Visual treatment uses the actual `BalanceCard` as the hero, so the user sees
/// exactly what they'll get on Home. A soft radial green blob sits behind it for
/// depth, and the elements stagger in with a spring entrance (skipped under
/// Reduce Motion).
struct WhatsNewBalanceModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppConfigViewModel.self) private var appConfig

    @State private var showEditSheet = false
    @State private var heroAppeared = false
    @State private var contentAppeared = false

    /// Culturally-plausible preview balance per locale so the hero looks like a
    /// real account, not a demo placeholder.
    private var previewBalance: Double {
        switch appConfig.config.currency {
        case "VND": return 12_500_000
        case "JPY": return 125_000
        case "EUR": return 2_345.67
        default:    return 2_345.67   // USD + fallback
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppTheme.spacing32) {
                    Spacer(minLength: AppTheme.spacing32)

                    heroPreview

                    titleBlock
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 16)

                    benefitsBlock
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 20)

                    Spacer(minLength: AppTheme.spacing16)
                }
            }

            ctaBlock
                .opacity(contentAppeared ? 1 : 0)
        }
        .interactiveDismissDisabled() // make the choice intentional
        .onAppear(perform: runEntranceAnimation)
        .sheet(isPresented: $showEditSheet, onDismiss: {
            // Mark-seen runs only after the edit sheet closes — if the user opens
            // the setup flow we still consider the WhatsNew "delivered" whether or
            // not they save (they made an intentional choice either way).
            dismissAndMarkSeen()
        }) {
            BalanceEditSheet()
        }
    }

    // MARK: - Hero

    /// Mini BalanceCard preview with a soft primaryGreen radial blob behind it.
    /// `allowsHitTesting(false)` makes the card non-interactive — it's there as a
    /// visual showcase of the feature, not a real entry point.
    private var heroPreview: some View {
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

            BalanceCard(
                currentBalance: previewBalance,
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
        .scaleEffect(heroAppeared ? 1.0 : 0.9)
        .opacity(heroAppeared ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.tr("balance.whatsnew_title", appConfig.language))
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(spacing: AppTheme.spacing8) {
            Text(L10n.tr("balance.whatsnew_title", appConfig.language))
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            Text(L10n.tr("balance.whatsnew_subtitle", appConfig.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.spacing16)
        }
    }

    // MARK: - Benefits

    private var benefitsBlock: some View {
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
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.primaryGreen)
                .frame(width: 22, height: 22)
                .padding(.top, 1)

            Text(L10n.tr(key, appConfig.language))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - CTA

    private var ctaBlock: some View {
        VStack(spacing: AppTheme.spacing8) {
            Button {
                showEditSheet = true
            } label: {
                HStack(spacing: AppTheme.spacing8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.headline)
                    Text(L10n.tr("balance.whatsnew_setup_cta", appConfig.language))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.adaptiveAccent(colorScheme))

            Button {
                dismissAndMarkSeen()
            } label: {
                Text(L10n.tr("balance.whatsnew_later_cta", appConfig.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacing8)
            }
        }
        .padding(.horizontal, AppTheme.spacing24)
        .padding(.bottom, AppTheme.spacing16)
    }

    // MARK: - Animation

    private func runEntranceAnimation() {
        if reduceMotion {
            // No spring, no offset — just a quick fade so the change is still
            // visually anchored without movement.
            withAnimation(.easeIn(duration: 0.2)) {
                heroAppeared = true
                contentAppeared = true
            }
            return
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            heroAppeared = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.18)) {
            contentAppeared = true
        }
    }

    // MARK: - Actions

    private func dismissAndMarkSeen() {
        appConfig.markBalanceWhatsNewSeen()
        dismiss()
    }
}

#Preview("Vietnamese") {
    let container = try! ModelContainer(
        for: Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self,
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
        for: Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    return WhatsNewBalanceModal()
        .modelContainer(container)
        .environment(AppConfigViewModel())
        .environment(BalanceService(modelContext: container.mainContext, autoObserve: false))
        .preferredColorScheme(.dark)
}
