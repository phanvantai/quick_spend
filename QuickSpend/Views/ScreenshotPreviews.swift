import SwiftUI
import SwiftData

// MARK: - Screenshot Sample Data

/// Helper to create an in-memory model container pre-loaded with sample data for screenshots
@MainActor
private func screenshotContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Transaction.self, Category.self, RecurringTemplate.self,
        configurations: config
    )
    let context = container.mainContext

    // Seed categories
    let categories = CategoryService.defaultCategories(language: "en")
    for category in categories {
        context.insert(category)
    }

    // Create sample transactions spread across the current month
    let calendar = Calendar.current
    let now = Date()
    let year = calendar.component(.year, from: now)
    let month = calendar.component(.month, from: now)

    func date(day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? now
    }

    // Previous month transactions (for % change calculation)
    let prevMonth = calendar.date(byAdding: .month, value: -1, to: now)!
    let prevYear = calendar.component(.year, from: prevMonth)
    let prevMonthNum = calendar.component(.month, from: prevMonth)

    func prevDate(day: Int) -> Date {
        calendar.date(from: DateComponents(year: prevYear, month: prevMonthNum, day: day)) ?? prevMonth
    }

    // Previous month data
    let prevTransactions: [(Double, String, String, TransactionType, Int)] = [
        (3200, "Monthly Salary", "salary", .income, 1),
        (180, "Grocery Shopping", "groceries", .expense, 5),
        (45, "Gas Station", "transport", .expense, 8),
        (120, "Electric Bill", "bills_utilities", .expense, 10),
        (65, "Dinner Out", "food_drink", .expense, 15),
        (250, "New Shoes", "shopping", .expense, 18),
        (35, "Movie Night", "entertainment", .expense, 22),
        (90, "Health Checkup", "health", .expense, 25),
    ]
    for (amount, note, catId, type, day) in prevTransactions {
        context.insert(Transaction(
            amount: amount, note: note, categoryId: catId,
            type: type, date: prevDate(day: day)
        ))
    }

    // Current month expenses
    let currentTransactions: [(Double, String, String, TransactionType, Int)] = [
        // Income
        (3500, "Monthly Salary", "salary", .income, 1),
        (500, "Freelance Project", "freelance", .income, 5),
        (150, "Investment Return", "investment_income", .income, 12),
        (50, "Cash Gift", "gift_received", .income, 20),

        // Expenses - spread across the month
        (85, "Weekly Groceries", "groceries", .expense, 2),
        (12, "Morning Coffee", "food_drink", .expense, 2),
        (45, "Uber Ride", "transport", .expense, 3),
        (35, "Lunch with Team", "food_drink", .expense, 4),
        (120, "Grocery Shopping", "groceries", .expense, 5),
        (950, "Monthly Rent", "housing", .expense, 5),
        (25, "Spotify + Netflix", "entertainment", .expense, 6),
        (65, "Phone Bill", "bills_utilities", .expense, 7),
        (40, "Gas Station", "transport", .expense, 8),
        (28, "Pharmacy", "health", .expense, 9),
        (55, "Restaurant Dinner", "food_drink", .expense, 10),
        (90, "Online Shopping", "shopping", .expense, 11),
        (15, "Coffee Shop", "food_drink", .expense, 12),
        (180, "Electric Bill", "bills_utilities", .expense, 13),
        (35, "Book Purchase", "education", .expense, 14),
        (22, "Snacks", "food_drink", .expense, 15),
        (100, "Birthday Gift", "gifts", .expense, 16),
        (45, "Haircut", "personal_care", .expense, 17),
        (75, "Family Dinner", "family", .expense, 18),
        (200, "Insurance Premium", "insurance", .expense, 19),
        (60, "Pet Food", "pets", .expense, 20),
        (30, "Bus Pass", "transport", .expense, 21),
        (110, "Groceries", "groceries", .expense, 22),
        (18, "Cafe Latte", "food_drink", .expense, 23),
        (250, "Weekend Trip", "travel", .expense, 24),
        (42, "Gym Membership", "health", .expense, 25),
    ]
    for (amount, note, catId, type, day) in currentTransactions {
        let d = date(day: day)
        if d <= now {
            context.insert(Transaction(
                amount: amount, note: note, categoryId: catId,
                type: type, date: d
            ))
        }
    }

    // Historical months for trend chart (2-12 months back)
    let monthlyData: [(Int, [(Double, String, TransactionType)])] = [
        (-2, [(3100, "salary", .income), (450, "freelance", .income), (780, "food_drink", .expense), (200, "transport", .expense), (950, "housing", .expense), (150, "entertainment", .expense)]),
        (-3, [(3200, "salary", .income), (300, "bonus", .income), (650, "food_drink", .expense), (180, "transport", .expense), (950, "housing", .expense), (300, "shopping", .expense)]),
        (-4, [(3000, "salary", .income), (600, "food_drink", .expense), (220, "transport", .expense), (950, "housing", .expense), (100, "health", .expense)]),
        (-5, [(3100, "salary", .income), (200, "freelance", .income), (700, "food_drink", .expense), (190, "transport", .expense), (950, "housing", .expense), (250, "travel", .expense)]),
        (-6, [(3200, "salary", .income), (550, "food_drink", .expense), (210, "transport", .expense), (950, "housing", .expense), (180, "entertainment", .expense)]),
        (-7, [(3000, "salary", .income), (100, "interest", .income), (680, "food_drink", .expense), (170, "transport", .expense), (950, "housing", .expense)]),
        (-8, [(3100, "salary", .income), (720, "food_drink", .expense), (230, "transport", .expense), (950, "housing", .expense), (120, "gifts", .expense)]),
        (-9, [(3200, "salary", .income), (400, "bonus", .income), (600, "food_drink", .expense), (200, "transport", .expense), (950, "housing", .expense)]),
        (-10, [(3000, "salary", .income), (580, "food_drink", .expense), (190, "transport", .expense), (950, "housing", .expense), (80, "education", .expense)]),
        (-11, [(3100, "salary", .income), (150, "investment_income", .income), (650, "food_drink", .expense), (210, "transport", .expense), (950, "housing", .expense)]),
    ]
    for (offset, transactions) in monthlyData {
        let m = calendar.date(byAdding: .month, value: offset, to: now)!
        let y = calendar.component(.year, from: m)
        let mo = calendar.component(.month, from: m)
        let d = calendar.date(from: DateComponents(year: y, month: mo, day: 15))!
        for (amount, catId, type) in transactions {
            context.insert(Transaction(
                amount: amount, note: CategoryService.categoryName(for: catId, language: "en"),
                categoryId: catId, type: type, date: d
            ))
        }
    }

    return container
}

/// AppConfigViewModel configured for screenshots (English, USD)
private func screenshotAppConfig() -> AppConfigViewModel {
    let prefs = PreferencesService(defaults: UserDefaults(suiteName: "screenshot_preview_\(UUID().uuidString)")!)
    var config = prefs.getConfig()
    config.language = "en"
    config.currency = "USD"
    config.isOnboardingComplete = true
    config.themeMode = "light"
    prefs.saveConfig(config)
    return AppConfigViewModel(preferences: prefs)
}

// MARK: - Screenshot 1: Home Dashboard

#Preview("Screenshot - Home") {
    let container = try! screenshotContainer()
    HomeView()
        .modelContainer(container)
        .environment(screenshotAppConfig())
}

// MARK: - Screenshot 2: Transactions Calendar

#Preview("Screenshot - Transactions") {
    let container = try! screenshotContainer()
    TransactionsView()
        .modelContainer(container)
        .environment(screenshotAppConfig())
}

// MARK: - Screenshot 3: Report Analytics

#Preview("Screenshot - Report") {
    let container = try! screenshotContainer()
    let sub = SubscriptionViewModel(provider: MockPremiumProvider())
    NavigationStack {
        ReportDetailView()
    }
    .modelContainer(container)
    .environment(screenshotAppConfig())
    .environment(sub)
}

// MARK: - Screenshot 4: Voice Input Review

#Preview("Screenshot - Voice Review") {
    let container = try! screenshotContainer()
    let categories = CategoryService.defaultCategories(language: "en")

    let parsed = [
        ParsedTransaction(
            amount: 12.50,
            note: "Coffee at Starbucks",
            categoryId: "food_drink",
            type: .expense,
            date: .now,
            confidence: 0.95,
            rawInput: "coffee at starbucks twelve fifty"
        ),
        ParsedTransaction(
            amount: 45.00,
            note: "Uber to airport",
            categoryId: "transport",
            type: .expense,
            date: .now,
            confidence: 0.62,
            rawInput: "uber to airport forty five dollars"
        ),
    ]

    EditableExpenseDialog(
        parsedExpenses: parsed,
        categories: categories,
        onSave: { _ in }
    )
    .modelContainer(container)
    .environment(screenshotAppConfig())
}

// MARK: - Screenshot 5: Categories

#Preview("Screenshot - Categories") {
    let container = try! screenshotContainer()
    NavigationStack {
        CategoriesView()
    }
    .modelContainer(container)
    .environment(screenshotAppConfig())
}

// MARK: - Screenshot 6: Voice FAB Idle (Home with FAB visible)

#Preview("Screenshot - Voice FAB Idle") {
    let container = try! screenshotContainer()
    ZStack(alignment: .bottomTrailing) {
        HomeView()

        VoiceFABButton(
            language: "en",
            isRecording: false,
            soundLevel: 0,
            transcription: "",
            showTutorial: false,
            style: .audioBurst,
            onRecordStart: {},
            onRecordEnd: {},
            onRecordCancel: {},
            onTutorialDismissed: {}
        )
        .padding(.trailing, AppTheme.spacing16)
        .padding(.bottom, 90)
    }
    .modelContainer(container)
    .environment(screenshotAppConfig())
}

// MARK: - Screenshot 7: Voice FAB Recording with Transcription

#Preview("Screenshot - Voice Recording") {
    let container = try! screenshotContainer()
    ZStack(alignment: .bottomTrailing) {
        HomeView()

        // Recording bubble overlay (matches MainTabView layout)
        VStack {
            Spacer()
            RecordingBubbleView(
                language: "en",
                transcription: "Coffee at Starbucks twelve fifty",
                soundLevel: 0.6,
                isDragCancelling: false
            )
            .padding(.horizontal, AppTheme.spacing16)
            .padding(.bottom, 200)
        }

        VoiceFABButton(
            language: "en",
            isRecording: true,
            soundLevel: 0.6,
            transcription: "Coffee at Starbucks twelve fifty",
            showTutorial: false,
            style: .audioBurst,
            onRecordStart: {},
            onRecordEnd: {},
            onRecordCancel: {},
            onTutorialDismissed: {}
        )
        .padding(.trailing, AppTheme.spacing16)
        .padding(.bottom, 90)
    }
    .modelContainer(container)
    .environment(screenshotAppConfig())
}

// MARK: - Screenshot 8: Voice FAB Drag-to-Cancel

#Preview("Screenshot - Voice Cancel") {
    let container = try! screenshotContainer()
    ZStack(alignment: .bottomTrailing) {
        HomeView()

        // Cancel state bubble
        VStack {
            Spacer()
            RecordingBubbleView(
                language: "en",
                transcription: "Coffee at Starbucks twelve fifty",
                soundLevel: 0.4,
                isDragCancelling: true
            )
            .padding(.horizontal, AppTheme.spacing16)
            .padding(.bottom, 200)
        }

        // FAB in cancel state (red circle with X)
        ZStack {
            Circle()
                .fill(AppTheme.error.opacity(0.12))
                .frame(width: 100, height: 100)
            Circle()
                .fill(AppTheme.error.opacity(0.25))
                .frame(width: 84, height: 84)
            Circle()
                .fill(AppTheme.error)
                .frame(width: 68, height: 68)
                .shadow(color: AppTheme.error.opacity(0.35), radius: 12, x: 0, y: 6)
            Image(systemName: "xmark")
                .font(.title.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.trailing, AppTheme.spacing16)
        .padding(.bottom, 90)
    }
    .modelContainer(container)
    .environment(screenshotAppConfig())
}

// MARK: - Screenshot 9: Voice FAB Tutorial Tooltip

#Preview("Screenshot - Voice Tutorial") {
    ZStack(alignment: .bottomTrailing) {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()

        VoiceFABButton(
            language: "en",
            isRecording: false,
            soundLevel: 0,
            transcription: "",
            showTutorial: true,
            style: .audioBurst,
            onRecordStart: {},
            onRecordEnd: {},
            onRecordCancel: {},
            onTutorialDismissed: {}
        )
        .padding(.trailing, AppTheme.spacing16)
        .padding(.bottom, 90)
    }
    .environment(screenshotAppConfig())
}

// MARK: - Screenshot 10: Processing Indicator

#Preview("Screenshot - Voice Processing") {
    ZStack(alignment: .bottomTrailing) {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()

        VStack {
            Spacer()
            HStack(spacing: AppTheme.spacing8) {
                ProgressView()
                    .tint(.white)
                Text("Processing...")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, AppTheme.spacing16)
            .padding(.vertical, AppTheme.spacing12)
            .background(
                Capsule()
                    .fill(AppTheme.primaryGradient)
            )
            .padding(.bottom, 100)
            .frame(maxWidth: .infinity)
        }

        VoiceFABButton(
            language: "en",
            isRecording: false,
            soundLevel: 0,
            transcription: "",
            showTutorial: false,
            style: .audioBurst,
            onRecordStart: {},
            onRecordEnd: {},
            onRecordCancel: {},
            onTutorialDismissed: {}
        )
        .opacity(0.5)
        .padding(.trailing, AppTheme.spacing16)
        .padding(.bottom, 90)
    }
    .environment(screenshotAppConfig())
}

// MARK: - Mock Premium Provider

private struct MockPremiumProvider: SubscriptionProvider {
    func configure() {}
    func checkPremiumStatus() async -> Bool { true }
    func loadPrices() async -> (monthly: String?, yearly: String?) { ("$2.99", "$24.99") }
    func purchase(monthly: Bool) async -> Bool { true }
    func restorePurchases() async -> Bool { true }
}
