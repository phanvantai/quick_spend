import SwiftUI
import SwiftData

struct WalletManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]

    @State private var showCreateWallet = false
    @State private var editingWallet: Wallet?

    private var activeWallets: [Wallet] {
        wallets.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            List {
                if activeWallets.count == 1 {
                    Section {
                        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
                            Text(L10n.tr("wallets.education_title", appConfig.language))
                                .font(Typography.bodyEmphasized)
                            Text(L10n.tr("wallets.education_subtitle", appConfig.language))
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, AppTheme.spacing8)
                    }
                }

                Section(L10n.tr("wallets.title", appConfig.language)) {
                    ForEach(activeWallets, id: \.id) { wallet in
                        HStack(spacing: AppTheme.spacing12) {
                            CategoryIconBadge(iconName: wallet.iconName, color: wallet.color, size: 36, iconFont: .body)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(wallet.displayName(language: appConfig.language))
                                if wallet.id == appConfig.defaultWalletId {
                                    Text(L10n.tr("wallets.default", appConfig.language))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if wallet.id != appConfig.defaultWalletId {
                                Button(L10n.tr("wallets.make_default", appConfig.language)) {
                                    appConfig.setDefaultWalletId(wallet.id)
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            if wallet.id != Wallet.personalID {
                                Button(role: .destructive) {
                                    archive(wallet)
                                } label: {
                                    Label(L10n.tr("wallets.archive", appConfig.language), systemImage: "archivebox.fill")
                                }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                editingWallet = wallet
                            } label: {
                                Label(L10n.tr("common.edit", appConfig.language), systemImage: "pencil")
                            }
                            .tint(AppTheme.adaptiveAccent(colorScheme))
                        }
                    }
                }
            }
            .navigationTitle(L10n.tr("wallets.title", appConfig.language))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateWallet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showCreateWallet) {
                WalletFormView()
            }
            .sheet(item: $editingWallet) { wallet in
                WalletFormView(existingWallet: wallet)
            }
        }
    }

    private func archive(_ wallet: Wallet) {
        wallet.isArchived = true
        wallet.updatedAt = Date()
        if appConfig.defaultWalletId == wallet.id {
            appConfig.setDefaultWalletId(Wallet.personalID)
        }
        if appConfig.selectedWalletScope == .wallet(wallet.id) {
            appConfig.setSelectedWalletScope(.wallet(Wallet.personalID))
        }
        try? modelContext.save()
    }
}
