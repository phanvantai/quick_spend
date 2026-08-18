import SwiftUI
import SwiftData

/// One enum represents every modal that can present from Settings. Routing
/// through a single `.sheet(item:)` modifier on the NavigationStack avoids
/// the "two sheets both vanish" bug we hit when each section owned its own
/// `.sheet` modifier on a `Section` deep inside the list.
enum SettingsSheet: Hashable, Identifiable {
    case balanceEdit
    case currencyPicker
    case languagePicker
    case themePicker
    case wallets
    case paywall
    case premiumStatus

    var id: Self { self }
}

/// Settings screen with grouped sections.
///
/// v3.0: presented as a sheet from the Home/Transactions toolbar gear icon,
/// not a root tab. A Done button in the toolbar closes the sheet.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(SubscriptionViewModel.self) private var subscription
    @Environment(BalanceService.self) private var balanceService

    @Query private var transactions: [Transaction]

    @State private var activeSheet: SettingsSheet?
    @State private var showRestoreAlert = false
    @State private var restoreSuccess = false
    @State private var isRestoring = false
    @State private var showDeleteAllConfirm = false

    /// Currency cannot be changed once transactions exist to prevent data integrity issues.
    private var isCurrencyLocked: Bool {
        !transactions.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                CoreSection(
                    isCurrencyLocked: isCurrencyLocked,
                    activeSheet: $activeSheet
                )
                SubscriptionSection(
                    isRestoring: $isRestoring,
                    showRestoreAlert: $showRestoreAlert,
                    restoreSuccess: $restoreSuccess,
                    activeSheet: $activeSheet
                )
                DataSection(showDeleteAllConfirm: $showDeleteAllConfirm)
                PreferencesSection(activeSheet: $activeSheet)
            }
            .navigationTitle(L10n.tr("settings.title", appConfig.language))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.done", appConfig.language)) {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isRestoring {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                sheetContent(for: sheet)
            }
            .alert(
                L10n.tr("paywall.restore", appConfig.language),
                isPresented: $showRestoreAlert
            ) {
                Button(L10n.tr("common.close", appConfig.language), role: .cancel) { }
            } message: {
                if restoreSuccess {
                    Text(L10n.tr("settings.restore_success", appConfig.language))
                } else {
                    Text(L10n.tr("paywall.restore_no_purchases", appConfig.language))
                }
            }
            .alert(
                L10n.tr("settings.delete_all_data_confirm_title", appConfig.language),
                isPresented: $showDeleteAllConfirm
            ) {
                Button(L10n.tr("common.cancel", appConfig.language), role: .cancel) { }
                Button(L10n.tr("common.delete", appConfig.language), role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text(L10n.tr("settings.delete_all_data_confirm_message", appConfig.language))
            }
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: SettingsSheet) -> some View {
        switch sheet {
        case .balanceEdit:
            BalanceEditSheet(walletId: appConfig.defaultWalletId)
        case .currencyPicker:
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
                    activeSheet = nil
                },
                onDone: { activeSheet = nil }
            )
        case .languagePicker:
            PickerSheet(
                title: L10n.tr("settings.language", appConfig.language),
                doneText: L10n.tr("common.done", appConfig.language),
                items: LanguageOption.options,
                selectedId: appConfig.language,
                icon: { $0.flag },
                iconStyle: .custom,
                label: { $0.displayName },
                onSelect: { option in
                    appConfig.setLanguage(option.code)
                    CategoryService.updateCategoryNames(
                        language: option.code,
                        modelContext: modelContext
                    )
                    activeSheet = nil
                },
                onDone: { activeSheet = nil }
            )
        case .themePicker:
            PickerSheet(
                title: L10n.tr("settings.theme", appConfig.language),
                doneText: L10n.tr("common.done", appConfig.language),
                items: ThemeOption.options(language: appConfig.language),
                selectedId: appConfig.themeMode,
                icon: { $0.icon },
                iconStyle: .sfSymbol(.primary),
                label: { $0.title },
                onSelect: { option in
                    appConfig.setThemeMode(option.code)
                    activeSheet = nil
                },
                onDone: { activeSheet = nil }
            )
        case .wallets:
            WalletManagementView()
        case .paywall:
            PaywallView()
        case .premiumStatus:
            PremiumStatusSheet()
        }
    }

    private func deleteAllData() {
        do {
            try modelContext.delete(model: Transaction.self)
            try modelContext.delete(model: Category.self)
            try modelContext.delete(model: RecurringTemplate.self)
            try modelContext.delete(model: BalanceAnchor.self)
            try modelContext.delete(model: Wallet.self)
            try? WalletService.bootstrapIfNeeded(modelContext: modelContext)
        } catch {
            print("[Settings] Failed to delete data: \(error)")
        }
        appConfig.resetAll()
        balanceService.clearAll()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self, Wallet.self], inMemory: true)
        .environment(AppConfigViewModel())
        .environment(SubscriptionViewModel())
        .environment(CloudSyncService())
}
