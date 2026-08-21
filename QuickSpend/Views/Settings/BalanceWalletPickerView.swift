import SwiftUI
import SwiftData

struct BalanceWalletPickerView: View {
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(BalanceService.self) private var balanceService
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]

    @State private var editingWallet: Wallet?

    private var activeWallets: [Wallet] {
        wallets.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(activeWallets, id: \.id) { wallet in
                        Button {
                            editingWallet = wallet
                        } label: {
                            HStack(spacing: AppTheme.spacing12) {
                                CategoryIconBadge(
                                    iconName: wallet.iconName,
                                    color: wallet.color,
                                    size: 36,
                                    iconFont: .body
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(wallet.displayName(language: appConfig.language))
                                        .foregroundStyle(.primary)

                                    Text(balanceSubtitle(for: wallet))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
            .navigationTitle(L10n.tr("settings.balance", appConfig.language))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingWallet) { wallet in
                BalanceEditSheet(walletId: wallet.id)
            }
        }
    }

    private func balanceSubtitle(for wallet: Wallet) -> String {
        if let currentBalance = balanceService.currentBalance(for: wallet.id) {
            return appConfig.config.formatCurrency(currentBalance)
        }
        return L10n.tr("balance.not_set", appConfig.language)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self, Wallet.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    return BalanceWalletPickerView()
        .modelContainer(container)
        .environment(AppConfigViewModel())
        .environment(BalanceService(modelContext: container.mainContext, autoObserve: false))
}
