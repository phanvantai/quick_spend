import SwiftUI
import SwiftData

/// Core actions: balance, categories, recurring templates, Siri shortcut, currency.
struct CoreSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]

    let isCurrencyLocked: Bool
    @Binding var activeSheet: SettingsSheet?

    private var activeWallets: [Wallet] {
        wallets.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        Section {
            Button {
                activeSheet = .wallets
            } label: {
                SettingsRow(
                    icon: "wallet.pass.fill",
                    iconColor: AppTheme.incomeColor,
                    title: L10n.tr("wallets.title", appConfig.language),
                    subtitle: L10n.tr("wallets.settings_subtitle", appConfig.language)
                )
            }
            .tint(.primary)

            Button {
                activeSheet = activeWallets.count > 1 ? .balanceWalletPicker : .balanceEdit
            } label: {
                SettingsRow(
                    icon: "banknote.fill",
                    iconColor: AppTheme.adaptiveAccent(colorScheme),
                    title: L10n.tr("settings.balance", appConfig.language),
                    subtitle: L10n.tr(
                        activeWallets.count > 1 ? "settings.balance_wallets_subtitle" : "settings.balance_subtitle",
                        appConfig.language
                    )
                )
            }
            .tint(.primary)

            NavigationLink {
                CategoriesView()
            } label: {
                SettingsRow(
                    icon: "square.grid.2x2.fill",
                    iconColor: AppTheme.accentTeal,
                    title: L10n.tr("settings.categories", appConfig.language),
                    subtitle: L10n.tr("settings.categories_subtitle", appConfig.language)
                )
            }

            NavigationLink {
                RecurringListView()
            } label: {
                SettingsRow(
                    icon: "repeat",
                    iconColor: AppTheme.accentPink,
                    title: L10n.tr("settings.recurring", appConfig.language),
                    subtitle: L10n.tr("settings.recurring_subtitle", appConfig.language)
                )
            }

            Button {
                if let url = VoiceShortcut.installURL(for: appConfig.language) {
                    UIApplication.shared.open(url)
                }
            } label: {
                SettingsRow(
                    icon: "waveform.badge.plus",
                    iconColor: AppTheme.adaptiveAccent(colorScheme),
                    title: L10n.tr("voice_shortcut.settings_title", appConfig.language),
                    subtitle: L10n.tr("voice_shortcut.settings_subtitle", appConfig.language)
                )
            }
            .tint(.primary)

            Button {
                if !isCurrencyLocked {
                    activeSheet = .currencyPicker
                }
            } label: {
                HStack {
                    SettingsRow(
                        icon: "dollarsign.circle.fill",
                        iconColor: isCurrencyLocked ? .gray : AppTheme.accentOrange,
                        title: L10n.tr("settings.currency", appConfig.language),
                        subtitle: "\(appConfig.config.currencySymbol) \(appConfig.currency)"
                    )
                    if isCurrencyLocked {
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tint(.primary)
            .disabled(isCurrencyLocked)
        } footer: {
            VStack(alignment: .leading, spacing: AppTheme.spacing4) {
                Text(L10n.tr("settings.language_hint", appConfig.language))
                if isCurrencyLocked {
                    Text(L10n.tr("settings.currency_locked_hint", appConfig.language))
                }
            }
        }
    }
}
