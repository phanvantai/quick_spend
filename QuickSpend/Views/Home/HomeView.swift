import SwiftUI
import SwiftData

/// Home screen: monthly summary card + transaction list grouped by date
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(BalanceService.self) private var balance
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var selectedMonth = Date()
    @State private var showAddTransaction = false
    @State private var showBalanceEdit = false

    // MARK: - Selected Month Data

    private var monthTransactions: [Transaction] {
        let calendar = Calendar.current
        return allTransactions.filter {
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
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

    // MARK: - Previous Month (for % change)

    private var previousMonthTransactions: [Transaction] {
        let calendar = Calendar.current
        guard let prevMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) else { return [] }
        return allTransactions.filter {
            calendar.isDate($0.date, equalTo: prevMonth, toGranularity: .month)
        }
    }

    private var previousTotalExpenses: Double {
        previousMonthTransactions.filter(\.isExpense).reduce(0) { $0 + $1.amount }
    }

    private var previousTotalIncome: Double {
        previousMonthTransactions.filter(\.isIncome).reduce(0) { $0 + $1.amount }
    }

    private var expenseChangePercent: Double {
        guard previousTotalExpenses > 0 else { return 0 }
        return ((totalExpenses - previousTotalExpenses) / previousTotalExpenses) * 100
    }

    private var incomeChangePercent: Double {
        guard previousTotalIncome > 0 else { return 0 }
        return ((totalIncome - previousTotalIncome) / previousTotalIncome) * 100
    }

    // MARK: - Category Breakdown (for pie chart)

    private var expenseBreakdown: [CategoryStats] {
        buildCategoryBreakdown(for: .expense)
    }

    private var incomeBreakdown: [CategoryStats] {
        buildCategoryBreakdown(for: .income)
    }

    private func buildCategoryBreakdown(for type: TransactionType) -> [CategoryStats] {
        let typed = monthTransactions.filter { $0.type == type }
        let total = typed.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return [] }

        let grouped = Dictionary(grouping: typed) { $0.categoryId }
        return grouped.compactMap { (categoryId, transactions) -> CategoryStats? in
            guard let category = categories.first(where: { $0.id == categoryId }) else { return nil }
            let amount = transactions.reduce(0) { $0 + $1.amount }
            return CategoryStats(
                categoryId: categoryId,
                categoryName: category.name,
                totalAmount: amount,
                count: transactions.count,
                percentage: (amount / total) * 100,
                colorHex: category.colorHex,
                iconName: category.iconName,
                type: type
            )
        }
        .sorted { $0.totalAmount > $1.totalAmount }
    }

    // MARK: - 12-Month Trend Data (always from current date)

    private var trendData: [MonthlyTrend] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<12).reversed().map { offset -> MonthlyTrend in
            let month = calendar.date(byAdding: .month, value: -offset, to: now)!
            let monthTx = allTransactions.filter {
                calendar.isDate($0.date, equalTo: month, toGranularity: .month)
            }
            return MonthlyTrend(
                month: month,
                monthLabel: HomeStrings.monthAbbreviation(for: month, language: appConfig.language),
                totalExpenses: monthTx.filter(\.isExpense).reduce(0) { $0 + $1.amount },
                totalIncome: monthTx.filter(\.isIncome).reduce(0) { $0 + $1.amount }
            )
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppTheme.spacing16) {
                    // All-time account balance — sits above the month picker so it's
                    // visually separate from the month-scoped numbers below.
                    BalanceCard(
                        currentBalance: balance.currentBalance,
                        language: appConfig.language,
                        currency: appConfig.config.currency,
                        onTap: { showBalanceEdit = true }
                    )

                    // Month selector + currency badge (pinned via LazyVStack below)
                    HomeAppBar(
                        selectedMonth: $selectedMonth,
                        language: appConfig.language,
                        currency: appConfig.config.currency
                    )

                    // Overview: vertical bar chart (income vs expense)
                    OverviewSection(
                        totalExpenses: totalExpenses,
                        totalIncome: totalIncome,
                        netBalance: netBalance,
                        expenseChangePercent: expenseChangePercent,
                        incomeChangePercent: incomeChangePercent,
                        language: appConfig.language,
                        currency: appConfig.config.currency
                    )

                    // Report: pie/donut chart by category
                    ReportSection(
                        expenseBreakdown: expenseBreakdown,
                        incomeBreakdown: incomeBreakdown,
                        totalExpenses: totalExpenses,
                        totalIncome: totalIncome,
                        expenseChangePercent: expenseChangePercent,
                        incomeChangePercent: incomeChangePercent,
                        language: appConfig.language,
                        currency: appConfig.config.currency
                    )

                    // View Report button
                    NavigationLink {
                        ReportView()
                    } label: {
                        HStack {
                            Text(L10n.tr("home.view_report", appConfig.language))
                                .font(.subheadline.weight(.medium))
                            Image(systemName: "arrow.right")
                                .font(.subheadline)
                        }
                        .foregroundStyle(AppTheme.primaryDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.spacing12)
                        .background {
                            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                .stroke(AppTheme.primaryDark, lineWidth: 1)
                        }
                    }

                    // Trends: 12-month line chart (always from current date)
                    TrendsSection(
                        trendData: trendData,
                        language: appConfig.language,
                        currency: appConfig.config.currency
                    )
                }
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.top, AppTheme.spacing12)
                .padding(.bottom, AppTheme.spacing12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.tr("home.title", appConfig.language))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddTransaction = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                TransactionFormView(categories: categories) { transaction in
                    modelContext.insert(transaction)
                    balance.applyOptimisticInsert(transaction)
                }
            }
            .sheet(isPresented: $showBalanceEdit) {
                BalanceEditSheet()
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    return HomeView()
        .modelContainer(container)
        .environment(AppConfigViewModel())
        .environment(BalanceService(modelContext: container.mainContext, autoObserve: false))
}
