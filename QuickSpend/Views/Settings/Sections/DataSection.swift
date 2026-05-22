import SwiftUI
import SwiftData

/// iCloud sync status + destructive delete-all action.
struct DataSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(CloudSyncService.self) private var cloudSync
    @Environment(BalanceService.self) private var balanceService

    @State private var showDeleteAllConfirm = false

    var body: some View {
        Section {
            HStack(spacing: AppTheme.spacing12) {
                CategoryIconBadge(
                    iconName: cloudSync.isEnabled ? "icloud.fill" : "icloud.slash.fill",
                    color: cloudSync.isEnabled ? AppTheme.adaptiveAccent(colorScheme) : .gray,
                    size: 36,
                    iconFont: .body
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("settings.icloud_sync", appConfig.language))
                        .font(.body)
                    HStack(spacing: 4) {
                        if cloudSync.isSyncing {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                        Text(iCloudStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if cloudSync.isEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.body)
                }
            }
            .padding(.vertical, 2)

            Button(role: .destructive) {
                showDeleteAllConfirm = true
            } label: {
                SettingsRow(
                    icon: "trash.fill",
                    iconColor: .red,
                    title: L10n.tr("settings.delete_all_data", appConfig.language),
                    subtitle: L10n.tr("settings.delete_all_data_subtitle", appConfig.language)
                )
            }
        } header: {
            Text(L10n.tr("settings.data", appConfig.language))
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

    private var iCloudStatusText: String {
        switch cloudSync.iCloudStatus {
        case .available:
            if cloudSync.isSyncing {
                return L10n.tr("settings.icloud_syncing", appConfig.language)
            } else if cloudSync.lastSyncDate != nil {
                return L10n.tr("settings.icloud_synced", appConfig.language)
            } else {
                return L10n.tr("settings.icloud_connected", appConfig.language)
            }
        case .noAccount:
            return L10n.tr("settings.icloud_no_account", appConfig.language)
        case .restricted:
            return L10n.tr("settings.icloud_restricted", appConfig.language)
        case .temporarilyUnavailable:
            return L10n.tr("settings.icloud_unavailable", appConfig.language)
        case .unknown:
            return L10n.tr("settings.icloud_unknown", appConfig.language)
        }
    }

    private func deleteAllData() {
        do {
            try modelContext.delete(model: Transaction.self)
            try modelContext.delete(model: Category.self)
            try modelContext.delete(model: RecurringTemplate.self)
            try modelContext.delete(model: BalanceAnchor.self)
        } catch {
            print("[Settings] Failed to delete data: \(error)")
        }
        appConfig.resetAll()
        balanceService.clearAll()
    }
}
