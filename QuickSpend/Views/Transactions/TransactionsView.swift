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
    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @Query(sort: \QuickCategory.name) private var categories: [QuickCategory]

    @State private var selectedMonth = Date()
    @State private var selectedFilter: TransactionFilter = .all
    @State private var editingExpense: Expense?
    @State private var showingAddExpense = false

    /// Expenses filtered to the selected month
    private var monthExpenses: [Expense] {
        let calendar = Calendar.current
        return allExpenses.filter {
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    /// Expenses filtered by selected tab
    private var filteredExpenses: [Expense] {
        switch selectedFilter {
        case .all: return monthExpenses
        case .income: return monthExpenses.filter(\.isIncome)
        case .expense: return monthExpenses.filter(\.isExpense)
        }
    }

    /// Group expenses by day
    private var groupedExpenses: [(date: Date, expenses: [Expense])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredExpenses) { expense in
            calendar.startOfDay(for: expense.date)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, expenses: $0.value.sorted { $0.date > $1.date }) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacing16) {
                    MonthNavigator(selectedMonth: $selectedMonth)

                    filterTabs

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
    private var expenseListSection: some View {
        if groupedExpenses.isEmpty {
            ContentUnavailableView(
                "No Transactions",
                systemImage: "tray",
                description: Text("No transactions this month.")
            )
            .padding(.top, AppTheme.spacing24)
        } else {
            LazyVStack(spacing: AppTheme.spacing20, pinnedViews: []) {
                ForEach(groupedExpenses, id: \.date) { group in
                    VStack(alignment: .leading, spacing: AppTheme.spacing12) {
                        dateSectionHeader(for: group.date)

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
