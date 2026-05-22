import SwiftUI

/// Premium / restore purchases / feature requests.
struct SubscriptionSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(SubscriptionViewModel.self) private var subscription

    @Binding var isRestoring: Bool
    @Binding var showRestoreAlert: Bool
    @Binding var restoreSuccess: Bool
    @Binding var activeSheet: SettingsSheet?

    var body: some View {
        Section(L10n.tr("settings.subscription", appConfig.language)) {
            if subscription.isPremium {
                Button {
                    activeSheet = .premiumStatus
                } label: {
                    SettingsRow(
                        icon: "star.fill",
                        iconColor: AppTheme.accentOrange,
                        title: L10n.tr("paywall.title", appConfig.language),
                        subtitle: L10n.tr("settings.premium_active", appConfig.language)
                    )
                }
                .tint(.primary)
            } else {
                Button {
                    activeSheet = .paywall
                } label: {
                    SettingsRow(
                        icon: "star.fill",
                        iconColor: AppTheme.accentOrange,
                        title: L10n.tr("common.upgrade_premium", appConfig.language),
                        subtitle: L10n.tr("settings.unlock_features", appConfig.language)
                    )
                }
                .tint(.primary)

                Button {
                    Task {
                        isRestoring = true
                        await subscription.restorePurchases()
                        isRestoring = false
                        restoreSuccess = subscription.isPremium
                        showRestoreAlert = true
                    }
                } label: {
                    SettingsRow(
                        icon: "arrow.clockwise",
                        iconColor: AppTheme.adaptiveAccent(colorScheme),
                        title: L10n.tr("paywall.restore", appConfig.language),
                        subtitle: L10n.tr("settings.restore_subtitle", appConfig.language)
                    )
                }
                .tint(.primary)
                .disabled(isRestoring)
            }

            NavigationLink {
                FeatureRequestListView()
            } label: {
                SettingsRow(
                    icon: "lightbulb.fill",
                    iconColor: AppTheme.adaptiveAccent(colorScheme),
                    title: L10n.tr("feature_request.title", appConfig.language),
                    subtitle: L10n.tr("settings.feature_request_subtitle", appConfig.language)
                )
            }
        }
    }
}
