#if DEBUG
import Foundation
import SwiftData

/// Sample data for App Store and landing page screenshots (DEBUG builds only).
///
/// Launch with `-ScreenshotDemo`:
/// `xcrun simctl launch <udid> com.randomtech.quickSpend -ScreenshotDemo`
/// The app then opens an in-memory store filled with this data, skips
/// onboarding, and acts as Pro. The real store and CloudKit are never opened.
/// Add `-AppleLanguages "(vi)"` for localized screenshots.
@MainActor
enum ScreenshotDemo {
    nonisolated static let launchArgument = "-ScreenshotDemo"

    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// `-ScreenshotDemoVoice "Coffee 5 dollars"` sends this text to the parser
    /// on launch, as if it had been spoken (the simulator has no microphone).
    static let voiceTextKey = "ScreenshotDemoVoice"

    static func voiceText(defaults: UserDefaults = .standard, arguments: [String] = ProcessInfo.processInfo.arguments) -> String? {
        guard arguments.contains(launchArgument),
              let text = defaults.string(forKey: voiceTextKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return text
    }

    static let bankWalletId = "demo_wallet_bank"
    static let savingsWalletId = "demo_wallet_savings"

    static func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: AppSchema.schema, configurations: config)
    }

    /// Skips onboarding and one-time promos so the app opens straight to Home.
    /// Voice sample sharing is turned off so demo use never reaches Firestore.
    static func preparePreferences(_ preferences: PreferencesService, language: String) {
        var config = preferences.getConfig()
        config.language = language
        config.currency = "USD"
        preferences.saveConfig(config)
        preferences.completeOnboarding()
        preferences.markVoiceShortcutPromoSeen()
        preferences.markVoiceTutorialShown()
        preferences.setShouldShowWalletsWhatsNew(false)
        preferences.setDefaultWalletId(Wallet.personalID)
        preferences.setSelectedWalletScope(.all)
        preferences.shareVoiceSamples = false
    }

    static func seed(
        into context: ModelContext,
        language: String,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws {
        for category in CategoryService.defaultCategories(language: language) {
            context.insert(category)
        }

        let personal = Wallet.personal()
        let bank = Wallet(id: bankWalletId, name: "Bank", iconName: "building.columns.fill", colorHex: "#2D6A4F", sortOrder: 1)
        let savings = Wallet(id: savingsWalletId, name: "Savings", iconName: "banknote.fill", colorHex: "#D97706", sortOrder: 2)
        [personal, bank, savings].forEach(context.insert)

        let thisMonth = calendar.dateInterval(of: .month, for: now)!.start
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: thisMonth)!

        /// Day `day` of the month starting at `month`, at noon, never after `now`.
        func date(_ month: Date, day: Int) -> Date {
            let value = calendar.date(byAdding: DateComponents(day: day - 1, hour: 12), to: month)!
            return min(value, now)
        }

        for (walletId, opening) in [(personal.id, 1_250.0), (bank.id, 4_800.0), (savings.id, 6_500.0)] {
            context.insert(BalanceAnchor(walletId: walletId, openingBalance: opening, anchorDate: lastMonth))
        }

        for (amount, note, categoryId, type, day) in previousMonth {
            context.insert(Transaction(
                amount: amount, note: note, categoryId: categoryId, walletId: personal.id,
                type: type, date: date(lastMonth, day: day)
            ))
        }
        // Older months only feed the 6-month trend chart.
        for (index, (income, spending)) in olderMonths.enumerated() {
            let month = calendar.date(byAdding: .month, value: -(index + 2), to: thisMonth)!
            context.insert(Transaction(
                amount: income, note: "Monthly Salary", categoryId: "salary", walletId: bank.id,
                type: .income, date: date(month, day: 1)
            ))
            for (offset, (share, note, categoryId)) in olderSpending.enumerated() {
                context.insert(Transaction(
                    amount: (spending * share).rounded(), note: note, categoryId: categoryId,
                    walletId: personal.id, type: .expense, date: date(month, day: 3 + offset * 5)
                ))
            }
        }
        for (amount, note, categoryId, type, day) in currentMonth {
            context.insert(Transaction(
                amount: amount, note: note, categoryId: categoryId,
                walletId: type == .income ? bank.id : personal.id,
                type: type, date: date(thisMonth, day: day)
            ))
        }

        let transfer = Transfer(
            fromWalletId: bank.id, toWalletId: savings.id, amount: 500,
            date: date(thisMonth, day: 2), note: "Monthly savings"
        )
        transfer.makeLegs().forEach(context.insert)

        for (amount, note, categoryId, type, walletId) in [
            (3_500.0, "Monthly Salary", "salary", TransactionType.income, bank.id),
            (950, "Monthly Rent", "housing", .expense, personal.id),
            (25, "Spotify + Netflix", "entertainment", .expense, personal.id),
            (65, "Phone Bill", "bills_utilities", .expense, personal.id),
        ] {
            context.insert(RecurringTemplate(
                amount: amount, note: note, categoryId: categoryId, walletId: walletId,
                type: type, pattern: .monthly, startDate: lastMonth, lastGeneratedDate: now
            ))
        }

        try context.save()
    }

    private typealias Row = (Double, String, String, TransactionType, Int)

    private static let previousMonth: [Row] = [
        (3_500, "Monthly Salary", "salary", .income, 1),
        (300, "Logo Design", "freelance", .income, 18),
        (950, "Monthly Rent", "housing", .expense, 1),
        (160, "Grocery Shopping", "groceries", .expense, 4),
        (45, "Gas Station", "transport", .expense, 8),
        (120, "Electric Bill", "bills_utilities", .expense, 10),
        (65, "Dinner Out", "food_drink", .expense, 14),
        (210, "New Shoes", "shopping", .expense, 18),
        (35, "Movie Night", "entertainment", .expense, 22),
        (90, "Health Checkup", "health", .expense, 25),
        (140, "Weekend Groceries", "groceries", .expense, 27),
    ]

    /// (income, total spending) for 2…5 months ago, newest first.
    private static let olderMonths: [(Double, Double)] = [
        (3_800, 1_950), (3_500, 2_300), (3_600, 1_700), (3_500, 2_050),
    ]

    private static let olderSpending: [(Double, String, String)] = [
        (0.5, "Monthly Rent", "housing"),
        (0.2, "Groceries", "groceries"),
        (0.12, "Dining Out", "food_drink"),
        (0.1, "Shopping", "shopping"),
        (0.08, "Utilities", "bills_utilities"),
    ]

    private static let currentMonth: [Row] = [
        (3_500, "Monthly Salary", "salary", .income, 1),
        (650, "Freelance Project", "freelance", .income, 5),
        (150, "Investment Return", "investment_income", .income, 12),
        (950, "Monthly Rent", "housing", .expense, 1),
        (85, "Weekly Groceries", "groceries", .expense, 2),
        (6, "Morning Coffee", "food_drink", .expense, 2),
        (18, "Uber Ride", "transport", .expense, 3),
        (32, "Lunch with Team", "food_drink", .expense, 4),
        (110, "Grocery Shopping", "groceries", .expense, 5),
        (25, "Spotify + Netflix", "entertainment", .expense, 6),
        (65, "Phone Bill", "bills_utilities", .expense, 7),
        (40, "Gas Station", "transport", .expense, 8),
        (28, "Pharmacy", "health", .expense, 9),
        (54, "Restaurant Dinner", "food_drink", .expense, 10),
        (89, "Running Shoes", "shopping", .expense, 11),
        (5, "Coffee Shop", "food_drink", .expense, 12),
        (60, "Online Course", "education", .expense, 13),
        (75, "Farmers Market", "groceries", .expense, 15),
        (12, "Bus Pass", "transport", .expense, 15),
        (38, "Concert Tickets", "entertainment", .expense, 16),
        (9, "Bubble Tea", "food_drink", .expense, 17),
    ]
}

/// Treats the demo as a Pro subscriber so every screen shows its full version.
struct ScreenshotDemoPremiumProvider: SubscriptionProvider {
    func configure() {}
    func checkPremiumStatus() async -> Bool { true }
    func loadPrices() async -> (monthly: String?, yearly: String?) { ("$2.99", "$24.99") }
    func purchase(monthly: Bool) async -> Bool { true }
    func restorePurchases() async -> Bool { true }
    func syncPurchases() async -> Bool { true }
}
#endif
