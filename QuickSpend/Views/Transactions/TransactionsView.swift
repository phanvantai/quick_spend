import SwiftUI
import SwiftData

/// Transaction filter options
enum TransactionFilter: CaseIterable {
    case all, income, expense

    func label(language: String) -> String {
        switch self {
        case .all:
            return L10n.tr("transactions.all", language)
        case .income:
            return L10n.tr("transactions.filter_income", language)
        case .expense:
            return L10n.tr("transactions.filter_expense", language)
        }
    }
}

/// Transaction list view with month navigation and filter tabs
struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var selectedMonth = Date()
    @State private var selectedFilter: TransactionFilter = .all
    @State private var editingTransaction: Transaction?
    @State private var showingAddTransaction = false

    /// Transactions filtered to the selected month
    private var monthTransactions: [Transaction] {
        let calendar = Calendar.current
        return allTransactions.filter {
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    /// Transactions filtered by selected tab
    private var filteredTransactions: [Transaction] {
        switch selectedFilter {
        case .all: return monthTransactions
        case .income: return monthTransactions.filter(\.isIncome)
        case .expense: return monthTransactions.filter(\.isExpense)
        }
    }

    /// Group transactions by day
    private var groupedTransactions: [(date: Date, transactions: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, transactions: $0.value.sorted { $0.date > $1.date }) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacing16) {
                    MonthNavigator(selectedMonth: $selectedMonth, language: appConfig.language)

                    filterTabs

                    transactionListSection
                }
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.bottom, AppTheme.spacing16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.tr("transactions.title", appConfig.language))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddTransaction = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddTransaction) {
                TransactionFormView(categories: categories) { transaction in
                    modelContext.insert(transaction)
                }
            }
            .sheet(item: $editingTransaction) { transaction in
                TransactionFormView(categories: categories, expense: transaction) { updated in
                    transaction.amount = updated.amount
                    transaction.note = updated.note
                    transaction.categoryId = updated.categoryId
                    transaction.date = updated.date
                    transaction.type = updated.type
                    transaction.updatedAt = .now
                }
            }
        }
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        HStack(spacing: 0) {
            ForEach(TransactionFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                } label: {
                    VStack(spacing: AppTheme.spacing8) {
                        Text(filter.label(language: appConfig.config.language))
                            .font(.subheadline.weight(selectedFilter == filter ? .semibold : .regular))
                            .foregroundStyle(selectedFilter == filter ? .primary : .secondary)

                        Rectangle()
                            .fill(selectedFilter == filter ? AppTheme.dashboardExpenseLine : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Expense List

    @ViewBuilder
    private var transactionListSection: some View {
        if groupedTransactions.isEmpty {
            ContentUnavailableView(
                L10n.tr("home.no_transactions", appConfig.language),
                systemImage: "tray",
                description: Text(L10n.tr("home.no_transactions_month", appConfig.language))
            )
            .padding(.top, AppTheme.spacing24)
        } else {
            LazyVStack(spacing: AppTheme.spacing20, pinnedViews: []) {
                ForEach(groupedTransactions, id: \.date) { group in
                    VStack(alignment: .leading, spacing: AppTheme.spacing12) {
                        dateSectionHeader(for: group.date)

                        ForEach(group.transactions, id: \.id) { transaction in
                            let category = categories.first { $0.id == transaction.categoryId }
                            TransactionCard(
                                transaction: transaction,
                                category: category,
                                config: appConfig.config
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteTransaction(transaction)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    editingTransaction = transaction
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(AppTheme.adaptiveAccent(colorScheme))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Date Section Header

    private func dateSectionHeader(for date: Date) -> some View {
        let locale = Locale(identifier: appConfig.language)
        return Text(date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().locale(locale)))
            .font(.subheadline.bold())
            .foregroundStyle(.primary)
            .padding(.leading, AppTheme.spacing4)
    }

    // MARK: - Actions

    private func deleteTransaction(_ transaction: Transaction) {
        withAnimation {
            modelContext.delete(transaction)
        }
    }
}

#Preview {
    TransactionsView()
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
}
