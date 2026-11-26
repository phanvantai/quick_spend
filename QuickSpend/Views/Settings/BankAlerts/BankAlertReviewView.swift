import SwiftUI
import SwiftData

/// "To review": bank alerts read by the generic parser (or all alerts, when
/// the user asked to review everything). Save, edit then save, or discard.
struct BankAlertReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(BalanceService.self) private var balanceService
    @Environment(SubscriptionViewModel.self) private var subscription
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]

    let store: BankAlertStore

    @State private var editing: PendingBankAlert?
    @State private var errorMessage: String?
    @State private var confirmDiscardAll = false

    private var language: String { appConfig.language }
    private func t(_ key: String) -> String { L10n.tr(key, language) }

    var body: some View {
        List {
            if store.pending.isEmpty {
                EmptyDataView(icon: "checkmark.circle", message: t("bank_alert.review.empty"), minHeight: 240)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(store.pending) { item in
                        Button { editing = item } label: { row(item) }
                            .tint(.primary)
                            .swipeActions(edge: .leading) {
                                Button { approve(item) } label: {
                                    Label(t("common.save"), systemImage: "checkmark")
                                }
                                .tint(AppTheme.incomeColor)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { store.discard(item) } label: {
                                    Label(t("common.discard"), systemImage: "trash")
                                }
                            }
                    }
                } footer: {
                    Text(t("bank_alert.review.footer"))
                }
            }
        }
        .navigationTitle(t("bank_alert.review.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !store.pending.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { approveAll() } label: {
                            Label(t("bank_alert.review.save_all"), systemImage: "checkmark.circle")
                        }
                        Button(role: .destructive) { confirmDiscardAll = true } label: {
                            Label(t("bank_alert.review.discard_all"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(item: $editing) { item in
            EditableExpenseDialog(
                parsedExpenses: [parsed(from: item)],
                categories: categories,
                wallets: WalletService.activeWallets(from: wallets),
                defaultWalletId: item.walletId
            ) { transactions in
                guard let edited = transactions.first else { return }
                try store.approve(item, edited: edited, isPremium: subscription.isPremium, in: modelContext, balanceService: balanceService)
            }
        }
        .confirmationDialog(
            t("bank_alert.review.discard_all_confirm"),
            isPresented: $confirmDiscardAll,
            titleVisibility: .visible
        ) {
            Button(t("bank_alert.review.discard_all"), role: .destructive) { store.discardAll() }
            Button(t("common.cancel"), role: .cancel) { }
        }
        .alert(
            t("transaction.save_error_title"),
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
            presenting: errorMessage
        ) { _ in
            Button(t("common.close")) { errorMessage = nil }
        } message: { message in
            Text(message)
        }
        .onAppear { store.reload() }
    }

    private func row(_ item: PendingBankAlert) -> some View {
        let category = categories.first { $0.id == item.categoryId }
        return HStack(spacing: AppTheme.spacing12) {
            CategoryIconBadge(
                iconName: category?.iconName ?? "building.columns.fill",
                color: Color(hex: category?.colorHex ?? "00897B"),
                size: 36,
                iconFont: .body
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(item.note)
                    .font(.body)
                    .lineLimit(2)
                Text([item.displayBankName, item.date.formatted(date: .abbreviated, time: .shortened)]
                    .compactMap { $0 }
                    .joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text((item.type == .income ? "+" : "−") + appConfig.config.formatCurrency(item.amount))
                .font(.body.weight(.semibold))
                .foregroundStyle(item.type == .income ? AppTheme.incomeColor : Color.primary)
        }
        .padding(.vertical, 2)
    }

    private func parsed(from item: PendingBankAlert) -> ParsedTransaction {
        var parsed = ParsedTransaction(
            amount: item.amount, note: item.note, categoryId: item.categoryId,
            type: item.type, date: item.date, confidence: 1
        )
        parsed.walletId = item.walletId
        return parsed
    }

    private func approve(_ item: PendingBankAlert) {
        do {
            try store.approve(item, in: modelContext, balanceService: balanceService)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func approveAll() {
        do {
            try store.approveAll(in: modelContext, balanceService: balanceService)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
