import SwiftUI
import SwiftData

/// Calendar-based transactions view with grouped expense list
struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @Query(sort: \QuickCategory.name) private var categories: [QuickCategory]

    @State private var selectedMonth = Date()
    @State private var selectedDate: Date?
    @State private var editingExpense: Expense?
    @State private var showingAddExpense = false

    /// Expenses filtered to the selected month
    private var monthExpenses: [Expense] {
        let calendar = Calendar.current
        return allExpenses.filter {
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    /// Expenses for the selected date, or all month expenses if no date selected
    private var displayedExpenses: [Expense] {
        guard let selectedDate else { return monthExpenses }
        let calendar = Calendar.current
        return monthExpenses.filter {
            calendar.isDate($0.date, equalTo: selectedDate, toGranularity: .day)
        }
    }

    /// Group expenses by day
    private var groupedExpenses: [(date: Date, expenses: [Expense])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: displayedExpenses) { expense in
            calendar.startOfDay(for: expense.date)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, expenses: $0.value.sorted { $0.date > $1.date }) }
    }

    private var monthlyIncome: Double {
        monthExpenses.filter(\.isIncome).reduce(0) { $0 + $1.amount }
    }

    private var monthlyExpense: Double {
        monthExpenses.filter(\.isExpense).reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacing16) {
                    MonthNavigator(selectedMonth: $selectedMonth)

                    MonthlySummaryCard(
                        income: monthlyIncome,
                        expense: monthlyExpense,
                        config: appConfig.config
                    )

                    CalendarGrid(
                        selectedMonth: selectedMonth,
                        expenses: allExpenses,
                        currency: appConfig.config.currency,
                        selectedDate: $selectedDate
                    )

                    // Selected date chip
                    if let selectedDate {
                        HStack {
                            Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                                .font(.subheadline.bold())
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    self.selectedDate = nil
                                }
                            } label: {
                                Label("Clear", systemImage: "xmark.circle.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, AppTheme.spacing4)
                    }

                    // Expense list
                    expenseListSection
                }
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.bottom, AppTheme.spacing16)
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddExpense = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                ExpenseFormView(categories: categories) { expense in
                    modelContext.insert(expense)
                }
            }
            .sheet(item: $editingExpense) { expense in
                ExpenseFormView(categories: categories, expense: expense) { updated in
                    expense.amount = updated.amount
                    expense.descriptionText = updated.descriptionText
                    expense.categoryId = updated.categoryId
                    expense.date = updated.date
                    expense.typeRawValue = updated.typeRawValue
                }
            }
            .onChange(of: selectedMonth) {
                selectedDate = nil
            }
        }
    }

    // MARK: - Expense List

    @ViewBuilder
    private var expenseListSection: some View {
        if groupedExpenses.isEmpty {
            ContentUnavailableView(
                selectedDate != nil ? "No Transactions" : "No Transactions This Month",
                systemImage: "tray",
                description: Text(selectedDate != nil
                    ? "No transactions on this date."
                    : "Add your first transaction to get started.")
            )
            .padding(.top, AppTheme.spacing24)
        } else {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(groupedExpenses, id: \.date) { group in
                    Section {
                        ForEach(group.expenses, id: \.id) { expense in
                            let category = categories.first { $0.id == expense.categoryId }
                            ExpenseCard(
                                expense: expense,
                                category: category,
                                config: appConfig.config
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteExpense(expense)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    editingExpense = expense
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(AppTheme.primaryMint)
                            }

                            if expense.id != group.expenses.last?.id {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    } header: {
                        dateSectionHeader(for: group.date, expenses: group.expenses)
                    }
                }
            }
        }
    }

    // MARK: - Date Section Header

    private func dateSectionHeader(for date: Date, expenses: [Expense]) -> some View {
        let dayIncome = expenses.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        let dayExpense = expenses.filter(\.isExpense).reduce(0) { $0 + $1.amount }

        return HStack {
            Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            Spacer()

            if dayIncome > 0 {
                Text("+\(appConfig.formatCurrency(dayIncome))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.incomeColor)
            }
            if dayExpense > 0 {
                Text("-\(appConfig.formatCurrency(dayExpense))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.expenseColor)
            }
        }
        .padding(.vertical, AppTheme.spacing8)
        .padding(.horizontal, AppTheme.spacing4)
        .background(.regularMaterial)
    }

    // MARK: - Actions

    private func deleteExpense(_ expense: Expense) {
        withAnimation {
            modelContext.delete(expense)
        }
    }
}

#Preview {
    TransactionsView()
        .modelContainer(for: [Expense.self, QuickCategory.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
}
