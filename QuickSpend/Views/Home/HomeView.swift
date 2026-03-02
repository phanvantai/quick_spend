import SwiftUI
import SwiftData

/// Home screen: monthly summary card + transaction list grouped by date
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var selectedMonth = Date()
    @State private var selectedFilter: TransactionFilter = .all
    @State private var editingTransaction: Transaction?
    @State private var showingAddTransaction = false

    // MARK: - Filtered Data

    private var monthTransactions: [Transaction] {
        let calendar = Calendar.current
        return allTransactions.filter {
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    private var filteredTransactions: [Transaction] {
        switch selectedFilter {
        case .all: return monthTransactions
        case .income: return monthTransactions.filter(\.isIncome)
        case .expense: return monthTransactions.filter(\.isExpense)
        }
    }

    private var groupedTransactions: [(date: Date, transactions: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, transactions: $0.value.sorted { $0.date > $1.date }) }
    }

    private var totalIncome: Double {
        monthTransactions.filter(\.isIncome).reduce(0) { $0 + $1.amount }
    }

    private var totalExpenses: Double {
        monthTransactions.filter(\.isExpense).reduce(0) { $0 + $1.amount }
    }

    private var netBalance: Double {
        totalIncome - totalExpenses
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacing16) {
                    HomeAppBar(
                        selectedMonth: $selectedMonth,
                        language: appConfig.language,
                        currency: appConfig.config.currency
                    )

                    summaryCard

                    filterTabs

                    transactionListSection
                }
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.vertical, AppTheme.spacing12)
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(Color(.systemGroupedBackground))
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

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: AppTheme.spacing12) {
            // Balance row
            HStack {
                Text(HomeStrings.balance(appConfig.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(appConfig.formatCurrency(netBalance))
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(netBalance >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor)
            }

            Divider()

            // Income / Expense row
            HStack {
                HStack(spacing: AppTheme.spacing8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(AppTheme.incomeColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(HomeStrings.income(appConfig.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(appConfig.formatCurrency(totalIncome))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(AppTheme.incomeColor)
                    }
                }

                Spacer()

                HStack(spacing: AppTheme.spacing8) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(HomeStrings.expense(appConfig.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(appConfig.formatCurrency(totalExpenses))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(AppTheme.expenseColor)
                    }
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(AppTheme.expenseColor)
                }
            }
        }
        .padding(AppTheme.spacing16)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .fill(Color(.secondarySystemGroupedBackground))
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
                        Text(filter.label(language: appConfig.language))
                            .font(.subheadline.weight(selectedFilter == filter ? .semibold : .regular))
                            .foregroundStyle(selectedFilter == filter ? .primary : .secondary)

                        Rectangle()
                            .fill(selectedFilter == filter ? AppTheme.primaryMint : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Transaction List

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
            LazyVStack(spacing: AppTheme.spacing20) {
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
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingTransaction = transaction
                            }
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
        let calendar = Calendar.current
        let label: String
        if calendar.isDateInToday(date) {
            label = appConfig.language == "vi" ? "Hôm nay" : "Today"
        } else if calendar.isDateInYesterday(date) {
            label = appConfig.language == "vi" ? "Hôm qua" : "Yesterday"
        } else {
            label = date.formatted(.dateTime.day(.twoDigits).month(.abbreviated).year())
        }
        return Text(label)
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
    HomeView()
        .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
}
