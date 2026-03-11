import SwiftUI

/// Sheet showing premium subscription benefits for active subscribers
struct PremiumStatusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacing24) {
                    heroSection
                    benefitsSection
                    thankYouSection
                }
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.bottom, AppTheme.spacing32)
            }
            .navigationTitle(L10n.tr("paywall.title", appConfig.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.close", appConfig.language)) {
                        dismiss()
                    }
                }
            }
            .tint(AppTheme.adaptiveAccent(colorScheme))
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: AppTheme.spacing16) {
            Circle()
                .fill(AppTheme.primaryGradient)
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "crown.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                }

            Text(L10n.tr("paywall.title", appConfig.language))
                .font(.title2.bold())

            Text(L10n.tr("premium_status.active_description", appConfig.language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppTheme.spacing16)
    }

    // MARK: - Benefits

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing12) {
            benefitRow(
                icon: "mic.fill",
                color: AppTheme.adaptiveAccent(colorScheme),
                title: L10n.tr("paywall.feature_voice", appConfig.language),
                subtitle: L10n.tr("paywall.feature_voice_desc", appConfig.language)
            )
            benefitRow(
                icon: "repeat",
                color: AppTheme.accentPink,
                title: L10n.tr("paywall.feature_recurring", appConfig.language),
                subtitle: L10n.tr("paywall.feature_recurring_desc", appConfig.language)
            )
            benefitRow(
                icon: "chart.bar.fill",
                color: AppTheme.accentOrange,
                title: L10n.tr("paywall.feature_reports", appConfig.language),
                subtitle: L10n.tr("paywall.feature_reports_desc", appConfig.language)
            )
            benefitRow(
                icon: "lightbulb.fill",
                color: AppTheme.accentTeal,
                title: L10n.tr("premium_status.feature_requests", appConfig.language),
                subtitle: L10n.tr("premium_status.feature_requests_desc", appConfig.language)
            )
        }
        .padding(AppTheme.spacing16)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .fill(.ultraThinMaterial)
        }
    }

    private func benefitRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: AppTheme.spacing12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(color.opacity(0.15))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.adaptiveAccent(colorScheme))
                .font(.body)
        }
    }

    // MARK: - Thank You

    private var thankYouSection: some View {
        Text(L10n.tr("premium_status.thank_you", appConfig.language))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, AppTheme.spacing8)
    }
}

#Preview {
    PremiumStatusSheet()
        .environment(AppConfigViewModel())
}
