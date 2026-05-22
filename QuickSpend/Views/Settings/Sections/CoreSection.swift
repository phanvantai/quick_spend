import SwiftUI
import SwiftData

/// Core actions: balance, categories, recurring templates, Siri shortcut, currency.
struct CoreSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig

    let isCurrencyLocked: Bool

    @State private var showCurrencyPicker = false
    @State private var showBalanceEdit = false

    var body: some View {
        Section {
            Button {
                showBalanceEdit = true
            } label: {
                SettingsRow(
                    icon: "banknote.fill",
                    iconColor: AppTheme.adaptiveAccent(colorScheme),
                    title: L10n.tr("settings.balance", appConfig.language),
                    subtitle: L10n.tr("settings.balance_subtitle", appConfig.language)
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
                    showCurrencyPicker = true
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
        .sheet(isPresented: $showBalanceEdit) {
            BalanceEditSheet()
        }
        .sheet(isPresented: $showCurrencyPicker) {
            PickerSheet(
                title: L10n.tr("settings.currency", appConfig.language),
                doneText: L10n.tr("common.done", appConfig.language),
                items: CurrencyOption.options,
                selectedId: appConfig.currency,
                icon: { $0.symbol },
                iconStyle: .plain(AppTheme.accentOrange),
                label: { $0.code },
                onSelect: { option in
                    appConfig.setCurrency(option.code)
                    showCurrencyPicker = false
                },
                onDone: { showCurrencyPicker = false }
            )
        }
    }
}
