import SwiftUI
import SwiftData

/// Home screen with month navigator, summary card, bar chart, and voice input
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @Query(sort: \QuickCategory.name) private var categories: [QuickCategory]

    @State private var selectedMonth = Date()
    @State private var showingAddExpense = false

    // Voice input state
    @State private var voiceService = VoiceService()
    @State private var usageLimitService = UsageLimitService()
    @State private var showVoiceOverlay = false
    @State private var showEditDialog = false
    @State private var parsedExpenses: [ParsedExpense] = []
    @State private var showPermissionAlert = false
    @State private var isParsingVoice = false

    /// Expenses filtered to the selected month
    private var monthExpenses: [Expense] {
        let calendar = Calendar.current
        return allExpenses.filter {
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    private var monthlyIncome: Double {
        monthExpenses.filter(\.isIncome).reduce(0) { $0 + $1.amount }
    }

    private var monthlyExpense: Double {
        monthExpenses.filter(\.isExpense).reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: AppTheme.spacing16) {
                        MonthNavigator(selectedMonth: $selectedMonth)

                        MonthlySummaryCard(
                            income: monthlyIncome,
                            expense: monthlyExpense,
                            config: appConfig.config
                        )

                        MonthlyBarChart(
                            selectedMonth: selectedMonth,
                            expenses: allExpenses,
                            config: appConfig.config
                        )

                        // Recent expenses for this month
                        if !monthExpenses.isEmpty {
                            recentExpensesSection
                        }
                    }
                    .padding(.horizontal, AppTheme.spacing16)
                    .padding(.bottom, AppTheme.spacing24)
                }
                .navigationTitle("Home")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            startVoiceInput()
                        } label: {
                            Image(systemName: "mic.fill")
                        }

                        Button {
                            showingAddExpense = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }

                // Voice overlay
                if showVoiceOverlay {
                    VoiceOverlay(
                        voiceService: voiceService,
                        onComplete: { text in
                            showVoiceOverlay = false
                            handleVoiceResult(text)
                        },
                        onCancel: {
                            voiceService.cancelListening()
                            showVoiceOverlay = false
                        }
                    )
                    .transition(.opacity)
                }

                // Parsing indicator
                if isParsingVoice {
                    parsingOverlay
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showVoiceOverlay)
            .sheet(isPresented: $showingAddExpense) {
                ExpenseFormView(categories: categories) { expense in
                    modelContext.insert(expense)
                }
            }
            .sheet(isPresented: $showEditDialog) {
                EditableExpenseDialog(
                    parsedExpenses: parsedExpenses,
                    categories: categories
                ) { expenses in
                    for expense in expenses {
                        modelContext.insert(expense)
                    }
                }
            }
            .alert("Microphone Permission Required", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Voice input requires microphone and speech recognition access. Please enable them in Settings.")
            }
        }
    }

    // MARK: - Parsing Overlay

    private var parsingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            VStack(spacing: AppTheme.spacing16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("Parsing with AI...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Recent Expenses

    private var recentExpensesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            HStack {
                Text("Recent")
                    .font(.headline)
                Spacer()
                Text("\(monthExpenses.count) transactions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(monthExpenses.prefix(10), id: \.id) { expense in
                expenseRow(expense)
            }
        }
        .padding(.top, AppTheme.spacing8)
    }

    private func expenseRow(_ expense: Expense) -> some View {
        HStack(spacing: AppTheme.spacing12) {
            let category = categories.first { $0.id == expense.categoryId }
            Image(systemName: category?.iconName ?? "questionmark.circle")
                .foregroundStyle(category?.color ?? .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.descriptionText)
                    .font(.body)
                    .lineLimit(1)
                Text(expense.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(appConfig.formatCurrency(expense.amount))
                .font(.body.monospacedDigit())
                .foregroundStyle(expense.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor)
        }
        .padding(.vertical, AppTheme.spacing4)
    }

    // MARK: - Voice Input Logic

    private func startVoiceInput() {
        Task {
            if !voiceService.isAuthorized {
                let granted = await voiceService.requestPermissions()
                if !granted {
                    showPermissionAlert = true
                    return
                }
            }

            do {
                try voiceService.startListening(language: appConfig.language)
                showVoiceOverlay = true
            } catch {
                print("[HomeView] Failed to start voice: \(error)")
            }
        }
    }

    private func handleVoiceResult(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if GeminiParserService.isAvailable && usageLimitService.canParse {
            isParsingVoice = true
            Task {
                let results = await GeminiParserService.parse(
                    input: text,
                    categories: categories,
                    language: appConfig.language,
                    usageLimitService: usageLimitService
                )

                isParsingVoice = false

                if results.isEmpty {
                    showingAddExpense = true
                } else {
                    parsedExpenses = results
                    showEditDialog = true
                }
            }
        } else {
            showingAddExpense = true
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Expense.self, QuickCategory.self, RecurringTemplate.self], inMemory: true)
        .environment(AppConfigViewModel())
}
