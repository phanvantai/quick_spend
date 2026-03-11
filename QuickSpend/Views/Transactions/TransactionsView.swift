import SwiftUI
import SwiftData

/// Transaction list view with month navigation, calendar grid, and grouped transaction list
struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var selectedMonth = Date()
    @State private var selectedDate: Date?
    @State private var editingTransaction: Transaction?
    @State private var deletingTransaction: Transaction?
    @State private var showingAddTransaction = false

    /// Transactions filtered to the selected month
    private var monthTransactions: [Transaction] {
        let calendar = Calendar.current
        return allTransactions.filter {
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    /// Transactions to display — filtered by selected date if one is tapped, otherwise all month
    private var displayedTransactions: [Transaction] {
        guard let selectedDate else { return monthTransactions }
        let calendar = Calendar.current
        return monthTransactions.filter {
            calendar.isDate($0.date, equalTo: selectedDate, toGranularity: .day)
        }
    }

    /// Group transactions by day
    private var groupedTransactions: [(date: Date, transactions: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: displayedTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, transactions: $0.value.sorted { $0.date > $1.date }) }
    }

    // MARK: - Monthly Totals

    private var totalIncome: Double {
        monthTransactions.filter(\.isIncome).reduce(0) { $0 + $1.amount }
    }

    private var totalExpense: Double {
        monthTransactions.filter(\.isExpense).reduce(0) { $0 + $1.amount }
    }

    private var netTotal: Double {
        totalIncome - totalExpense
    }

    // MARK: - Month Date Range Label

    private var monthDateRange: String {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: selectedMonth)
        guard let range = calendar.range(of: .day, in: .month, for: selectedMonth) else {
            return ""
        }
        let lastDay = range.count
        let month = String(format: "%02d", comps.month ?? 1)
        return "(01/\(month)–\(lastDay)/\(month))"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month navigator pinned above the list
                monthNavigatorWithRange
                    .padding(.vertical, AppTheme.spacing8)

                List {
                    // Calendar & summary header section
                    Section {
                        VStack(spacing: AppTheme.spacing16) {
                            CalendarGrid(
                                selectedMonth: selectedMonth,
                                expenses: monthTransactions,
                                currency: appConfig.config.currency,
                                language: appConfig.language,
                                selectedDate: $selectedDate
                            )

                            monthlySummarySection
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    // Transaction list grouped by date
                    transactionListSection
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
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
            .onChange(of: selectedMonth) {
                selectedDate = nil
            }
            .alert(
                L10n.tr("common.delete", appConfig.language),
                isPresented: Binding(
                    get: { deletingTransaction != nil },
                    set: { if !$0 { deletingTransaction = nil } }
                )
            ) {
                Button(L10n.tr("common.cancel", appConfig.language), role: .cancel) {
                    deletingTransaction = nil
                }
                Button(L10n.tr("common.delete", appConfig.language), role: .destructive) {
                    if let transaction = deletingTransaction {
                        deleteTransaction(transaction)
                    }
                    deletingTransaction = nil
                }
            } message: {
                Text(L10n.tr("transactions.delete_confirm", appConfig.language))
            }
        }
    }

    // MARK: - Month Navigator with Date Range

    private var monthNavigatorWithRange: some View {
        VStack(spacing: AppTheme.spacing4) {
            MonthNavigator(selectedMonth: $selectedMonth, language: appConfig.language)

            Text(monthDateRange)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Monthly Summary

    private var monthlySummarySection: some View {
        HStack(spacing: 0) {
            summaryColumn(
                title: HomeStrings.income(appConfig.language),
                amount: totalIncome,
                color: AppTheme.incomeColor
            )

            Divider()
                .frame(height: 40)

            summaryColumn(
                title: HomeStrings.expense(appConfig.language),
                amount: totalExpense,
                color: AppTheme.expenseColor
            )

            Divider()
                .frame(height: 40)

            summaryColumn(
                title: HomeStrings.balance(appConfig.language),
                amount: netTotal,
                color: netTotal >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor,
                showSign: true
            )
        }
        .cardBackground()
    }

    private func summaryColumn(title: String, amount: Double, color: Color, showSign: Bool = false) -> some View {
        VStack(spacing: AppTheme.spacing4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(showSign && amount >= 0 ? "+" : "")\(appConfig.config.formatCurrency(amount))")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Transaction List

    @ViewBuilder
    private var transactionListSection: some View {
        if groupedTransactions.isEmpty {
            Section {
                ContentUnavailableView(
                    L10n.tr("home.no_transactions", appConfig.language),
                    systemImage: "tray",
                    description: Text(L10n.tr("home.no_transactions_month", appConfig.language))
                )
                .padding(.top, AppTheme.spacing24)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            ForEach(groupedTransactions, id: \.date) { group in
                Section {
                    ForEach(group.transactions, id: \.id) { transaction in
                        let category = categories.first { $0.id == transaction.categoryId }
                        TransactionCard(
                            transaction: transaction,
                            category: category,
                            config: appConfig.config
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deletingTransaction = transaction
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
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
                } header: {
                    dateSectionHeader(for: group.date, transactions: group.transactions)
                        .padding(.horizontal, AppTheme.spacing4)
                }
            }
        }
    }

    // MARK: - Date Section Header

    private func dateSectionHeader(for date: Date, transactions: [Transaction]) -> some View {
        let locale = Locale(identifier: appConfig.language)
        let dayTotal = transactions.reduce(0.0) { result, tx in
            result + (tx.isIncome ? tx.amount : -tx.amount)
        }

        return HStack {
            Text(date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().locale(locale)))
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            Spacer()

            Text("\(dayTotal >= 0 ? "+" : "-")\(appConfig.config.formatCurrency(abs(dayTotal)))")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(dayTotal >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor)
        }
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
