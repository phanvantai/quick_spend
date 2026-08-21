import SwiftUI
import SwiftData

/// v3.0 Home screen.
///
/// Three vertical layers from top to bottom: BalanceHero (all-time balance),
/// HomeAppBar (month picker + currency badge), SummaryPills (income / expense
/// totals), FocalChartCard (donut by category or income-vs-expense bar). A
/// "View full report" link below opens ReportDetailView for the period-picker
/// drill-down. The Voice FAB is overlaid by MainTabView; the toolbar carries
/// the Settings (leading) and Add Manual (trailing) entry points.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Environment(BalanceService.self) private var balance
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]

    @State private var selectedMonth = Date()
    @State private var showAddTransaction = false
    @State private var showBalanceEdit = false
    @State private var showSettings = false
    @State private var showWalletsWhatsNew = false

    // MARK: - Selected Month Data

    private var monthTransactions: [Transaction] {
        let calendar = Calendar.current
        return scopedTransactions.filter {
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    private var activeWallets: [Wallet] {
        wallets.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var effectiveWalletScope: WalletScope {
        guard activeWallets.count > 1 else {
            return .wallet(activeWallets.first?.id ?? Wallet.personalID)
        }
        switch selectedWalletScope {
        case .all:
            return .all
        case .wallet(let walletId):
            return activeWallets.contains(where: { $0.id == walletId }) ? selectedWalletScope : .wallet(activeWallets.first?.id ?? Wallet.personalID)
        }
    }

    private var selectedWalletScope: WalletScope {
        appConfig.selectedWalletScope
    }

    private var selectedWalletScopeBinding: Binding<WalletScope> {
        Binding(
            get: { effectiveWalletScope },
            set: { appConfig.setSelectedWalletScope($0) }
        )
    }

    private var scopedTransactions: [Transaction] {
        switch effectiveWalletScope {
        case .all:
            let activeIds = Set(activeWallets.map(\.id))
            return allTransactions.filter { activeIds.contains($0.walletId) }
        case .wallet(let walletId):
            return allTransactions.filter { $0.walletId == walletId }
        }
    }

    private var displayedBalance: Double? {
        switch effectiveWalletScope {
        case .all:
            return try? balance.computeTotalBalance(walletIds: activeWallets.map(\.id))
        case .wallet(let walletId):
            return balance.currentBalance(for: walletId)
        }
    }

    private var defaultWalletIdForNewTransaction: String {
        switch effectiveWalletScope {
        case .all:
            return activeWallets.contains(where: { $0.id == appConfig.defaultWalletId })
                ? appConfig.defaultWalletId
                : Wallet.personalID
        case .wallet(let walletId):
            return walletId
        }
    }

    private var totalIncome: Double {
        monthTransactions.filter(\.isIncome).reduce(0) { $0 + $1.amount }
    }

    private var totalExpenses: Double {
        monthTransactions.filter(\.isExpense).reduce(0) { $0 + $1.amount }
    }

    // MARK: - Previous Month (for % change)

    private var previousMonthTransactions: [Transaction] {
        let calendar = Calendar.current
        guard let prevMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) else { return [] }
        return scopedTransactions.filter {
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

    // MARK: - Category Breakdown (expense, for FocalChartCard donut)

    private var expenseBreakdown: [CategoryStats] {
        let typed = monthTransactions.filter(\.isExpense)
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
                type: .expense
            )
        }
        .sorted { $0.totalAmount > $1.totalAmount }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppTheme.spacing16) {
                    BalanceHero(
                        currentBalance: displayedBalance,
                        monthlyNet: (totalIncome == 0 && totalExpenses == 0) ? nil : (totalIncome - totalExpenses),
                        language: appConfig.language,
                        currency: appConfig.config.currency,
                        onTap: { showBalanceEdit = true }
                    )

                    HomeAppBar(
                        selectedMonth: $selectedMonth,
                        language: appConfig.language,
                        currency: appConfig.config.currency
                    )

                    SummaryPills(
                        totalIncome: totalIncome,
                        totalExpense: totalExpenses,
                        incomeChangePercent: incomeChangePercent,
                        expenseChangePercent: expenseChangePercent,
                        language: appConfig.language,
                        currency: appConfig.config.currency
                    )

                    FocalChartCard(
                        selection: appConfig.focalChartPreference,
                        onSelectionChange: { appConfig.setFocalChartPreference($0) },
                        expenseBreakdown: expenseBreakdown,
                        totalIncome: totalIncome,
                        totalExpense: totalExpenses,
                        incomeChangePercent: incomeChangePercent,
                        expenseChangePercent: expenseChangePercent,
                        language: appConfig.language,
                        currency: appConfig.config.currency
                    )

                    NavigationLink {
                        ReportDetailView()
                    } label: {
                        HStack {
                            Text(L10n.tr("home.view_report", appConfig.language))
                                .font(Typography.bodyEmphasized)
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
                }
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.top, AppTheme.spacing12)
                .padding(.bottom, AppTheme.spacing12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .principal) {
                    WalletScopeMenu(
                        selectedScope: selectedWalletScopeBinding,
                        language: appConfig.language,
                        wallets: activeWallets
                    )
                }
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
                TransactionFormView(
                    categories: categories,
                    wallets: activeWallets,
                    defaultWalletId: defaultWalletIdForNewTransaction
                ) { transaction in
                    modelContext.insert(transaction)
                    balance.applyOptimisticInsert(transaction)
                }
            }
            .sheet(isPresented: $showBalanceEdit) {
                BalanceEditSheet(walletId: defaultWalletIdForNewTransaction)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showWalletsWhatsNew) {
                WalletWhatsNewModal(
                    onCreateWallet: {
                        appConfig.markWalletsWhatsNewSeen()
                        showWalletsWhatsNew = false
                        showSettings = true
                    },
                    onDismiss: {
                        appConfig.markWalletsWhatsNewSeen()
                        showWalletsWhatsNew = false
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                showWalletsWhatsNew = appConfig.shouldShowWalletsWhatsNew
            }
        }
    }

}

#Preview {
    let container = try! ModelContainer(
        for: Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self, Wallet.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    return HomeView()
        .modelContainer(container)
        .environment(AppConfigViewModel())
        .environment(BalanceService(modelContext: container.mainContext, autoObserve: false))
}
