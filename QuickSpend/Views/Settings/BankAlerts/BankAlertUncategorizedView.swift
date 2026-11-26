import SwiftUI
import SwiftData

/// "Uncategorized": bank-alert transactions still in "other". Tap a category
/// chip to file one. Premium users can have QuickSpend remember the choice for
/// that counterparty (a rule), which also files their other uncategorized
/// transactions. Free users see what Premium would do for them.
struct BankAlertUncategorizedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(SubscriptionViewModel.self) private var subscription
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    let store: BankAlertStore

    @State private var remember = true
    @State private var showPaywall = false
    @State private var errorMessage: String?

    private var language: String { appConfig.language }
    private func t(_ key: String) -> String { L10n.tr(key, language) }

    private var items: [Transaction] { store.uncategorizedTransactions(transactions) }

    var body: some View {
        List {
            if subscription.isPremium {
                Section {
                    Toggle(isOn: $remember) {
                        Text(t("bank_alert.uncategorized.remember"))
                    }
                    .tint(AppTheme.primaryGreen)
                } footer: {
                    Text(t("bank_alert.uncategorized.remember_footer"))
                }
            } else {
                Section {
                    Button { showPaywall = true } label: { PremiumCategorizationPromo(language: language) }
                        .tint(.primary)
                }
            }

            if items.isEmpty {
                EmptyDataView(icon: "checkmark.circle", message: t("bank_alert.uncategorized.empty"), minHeight: 200)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(items) { transaction in
                        row(transaction)
                            .swipeActions(edge: .trailing) {
                                Button { store.keepAsOther(transaction) } label: {
                                    Label(t("bank_alert.uncategorized.keep_other"), systemImage: "checkmark")
                                }
                                .tint(.gray)
                            }
                    }
                } footer: {
                    Text(t("bank_alert.uncategorized.footer"))
                }
            }
        }
        .navigationTitle(t("bank_alert.uncategorized.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert(
            t("transaction.save_error_title"),
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
            presenting: errorMessage
        ) { _ in
            Button(t("common.close")) { errorMessage = nil }
        } message: { Text($0) }
    }

    private func row(_ transaction: Transaction) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.note)
                        .font(.body)
                        .lineLimit(2)
                    Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text((transaction.isIncome ? "+" : "−") + appConfig.config.formatCurrency(transaction.amount))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(transaction.isIncome ? AppTheme.incomeColor : Color.primary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.spacing8) {
                    ForEach(choices(for: transaction.type)) { category in
                        Button { assign(transaction, to: category) } label: {
                            HStack(spacing: 4) {
                                Image(systemName: category.iconName)
                                Text(category.name)
                            }
                            .font(.caption)
                            .padding(.horizontal, AppTheme.spacing8)
                            .padding(.vertical, 6)
                            .foregroundStyle(Color(hex: category.colorHex))
                            .background(Capsule().fill(Color(hex: category.colorHex).opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Visible categories of the transaction's type, without the "other" it already has.
    private func choices(for type: TransactionType) -> [Category] {
        let fallback = BankAlertCategorizer.fallbackCategoryId(for: type)
        return categories.filter { $0.type == type && !$0.isHidden && $0.id != fallback }
    }

    private func assign(_ transaction: Transaction, to category: Category) {
        do {
            try store.assign(
                transaction,
                categoryId: category.id,
                remember: subscription.isPremium && remember,
                among: transactions,
                in: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Premium upsell for automatic categorization of bank alerts.
struct PremiumCategorizationPromo: View {
    let language: String

    var body: some View {
        HStack(spacing: AppTheme.spacing12) {
            CategoryIconBadge(iconName: "sparkles", color: AppTheme.accentOrange, size: 36, iconFont: .body)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppTheme.spacing4) {
                    Text(L10n.tr("bank_alert.categorize.promo_title", language))
                        .font(.body.weight(.semibold))
                    Text(L10n.tr("paywall.premium_label", language))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(AppTheme.accentOrange))
                }
                Text(L10n.tr("bank_alert.categorize.promo_subtitle", language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

/// Premium: the user's "always file <note> under <category>" rules.
struct BankAlertRulesView: View {
    @Environment(AppConfigViewModel.self) private var appConfig
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    let store: BankAlertStore

    private var language: String { appConfig.language }

    var body: some View {
        List {
            if store.rules.isEmpty {
                EmptyDataView(icon: "list.bullet.rectangle", message: L10n.tr("bank_alert.rules.empty", language), minHeight: 200)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(store.rules) { rule in
                        let category = categories.first { $0.id == rule.categoryId }
                        HStack(spacing: AppTheme.spacing12) {
                            CategoryIconBadge(
                                iconName: category?.iconName ?? "questionmark",
                                color: Color(hex: category?.colorHex ?? "8E8E93"),
                                size: 32,
                                iconFont: .subheadline
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.note)
                                    .lineLimit(2)
                                Text(category?.name ?? rule.categoryId)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { store.rules[$0] }.forEach(store.deleteRule)
                    }
                } footer: {
                    Text(L10n.tr("bank_alert.rules.footer", language))
                }
            }
        }
        .navigationTitle(L10n.tr("bank_alert.rules.title", language))
        .navigationBarTitleDisplayMode(.inline)
    }
}
