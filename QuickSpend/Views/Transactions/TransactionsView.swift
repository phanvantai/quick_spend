import SwiftUI
import SwiftData

/// Transaction filter options
enum TransactionFilter: CaseIterable {
    case all, income, expense

    func label(language: String) -> String {
        switch self {
        case .all:
            switch language {
            case "vi": return "Tất cả"
            case "ja": return "すべて"
            case "ko": return "전체"
            case "th": return "ทั้งหมด"
            case "es": return "Todos"
            default: return "All"
            }
        case .income:
            switch language {
            case "vi": return "Tiền vào"
            case "ja": return "収入"
            case "ko": return "수입"
            case "th": return "รายรับ"
            case "es": return "Ingresos"
            default: return "Income"
            }
        case .expense:
            switch language {
            case "vi": return "Tiền ra"
            case "ja": return "支出"
            case "ko": return "지출"
            case "th": return "รายจ่าย"
            case "es": return "Gastos"
            default: return "Expense"
            }
        }
    }
}

/// Transaction list view with month navigation and filter tabs
struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
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
                    MonthNavigator(selectedMonth: $selectedMonth)

                    filterTabs

                    transactionListSection
                }
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.bottom, AppTheme.spacing16)
            }
            .navigationTitle("Transactions")
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
                ExpenseFormView(categories: categories) { transaction in
                    modelContext.insert(transaction)
                }
            }
            .sheet(item: $editingTransaction) { transaction in
                ExpenseFormView(categories: categories, expense: transaction) { updated in
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
                "No Transactions",
                systemImage: "tray",
                description: Text("No transactions this month.")
            )
            .padding(.top, AppTheme.spacing24)
        } else {
            LazyVStack(spacing: AppTheme.spacing20, pinnedViews: []) {
                ForEach(groupedTransactions, id: \.date) { group in
                    VStack(alignment: .leading, spacing: AppTheme.spacing12) {
                        dateSectionHeader(for: group.date)

                        ForEach(group.transactions, id: \.id) { transaction in
                            let category = categories.first { $0.id == transaction.categoryId }
                            ExpenseCard(
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
                                .tint(AppTheme.primaryMint)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Date Section Header

    private func dateSectionHeader(for date: Date) -> some View {
        Text(date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))
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
