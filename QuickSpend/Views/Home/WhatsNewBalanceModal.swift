import SwiftUI
import SwiftData

/// One-time full-screen modal introducing the Account Balance feature to users
/// upgrading from v2.4. Fresh installs never see this — `completeOnboarding()`
/// flips `hasSeenBalanceWhatsNew = true` atomically with `isOnboardingComplete`.
///
/// Two paths:
/// - "Set up balance now" → opens BalanceEditSheet, then dismisses + marks seen
/// - "Set up later"       → dismisses + marks seen
struct WhatsNewBalanceModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig

    @State private var showEditSheet = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppTheme.spacing32) {
                    Spacer(minLength: AppTheme.spacing40)

                    Image(systemName: "banknote.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(AppTheme.primaryGreen)

                    VStack(spacing: AppTheme.spacing8) {
                        Text(L10n.tr("balance.whatsnew_title", appConfig.language))
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)

                        Text(L10n.tr("balance.whatsnew_subtitle", appConfig.language))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.spacing16)
                    }

                    VStack(alignment: .leading, spacing: AppTheme.spacing16) {
                        benefitRow(key: "balance.whatsnew_benefit_1")
                        benefitRow(key: "balance.whatsnew_benefit_2")
                        benefitRow(key: "balance.whatsnew_benefit_3")
                    }
                    .padding(.horizontal, AppTheme.spacing24)

                    Spacer(minLength: AppTheme.spacing24)
                }
            }

            VStack(spacing: AppTheme.spacing12) {
                Button {
                    showEditSheet = true
                } label: {
                    Text(L10n.tr("balance.whatsnew_setup_cta", appConfig.language))
                        .font(.headline)
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
        .interactiveDismissDisabled() // make the choice intentional
        .sheet(isPresented: $showEditSheet, onDismiss: {
            // Mark-seen runs only after the edit sheet closes — if the user opens
            // the setup flow we still consider the WhatsNew "delivered" whether or
            // not they save (they made an intentional choice either way).
            dismissAndMarkSeen()
        }) {
            BalanceEditSheet()
        }
    }

    private func benefitRow(key: String) -> some View {
        HStack(spacing: AppTheme.spacing12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.primaryGreen)
            Text(L10n.tr(key, appConfig.language))
                .font(.body)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }

    private func dismissAndMarkSeen() {
        appConfig.markBalanceWhatsNewSeen()
        dismiss()
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    return WhatsNewBalanceModal()
        .modelContainer(container)
        .environment(AppConfigViewModel())
        .environment(BalanceService(modelContext: container.mainContext, autoObserve: false))
}
