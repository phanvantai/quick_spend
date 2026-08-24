import Testing
import Foundation
@testable import QuickSpend

@Suite("RecurringTemplate Model Tests")
struct RecurringTemplateTests {

    @Test("RecurringTemplate initializes correctly")
    func testInitialization() {
        let start = Date()
        let template = RecurringTemplate(
            amount: 5000000,
            note: "Monthly rent",
            categoryId: "housing",
            type: .expense,
            pattern: .monthly,
            startDate: start
        )

        #expect(template.amount == 5000000)
        #expect(template.note == "Monthly rent")
        #expect(template.categoryId == "housing")
        #expect(template.type == .expense)
        #expect(template.pattern == .monthly)
        #expect(template.startDate == start)
        #expect(template.endDate == nil)
        #expect(template.isActive == true)
        #expect(template.lastGeneratedDate == nil)
        #expect(!template.id.isEmpty)
        #expect(template.walletId == Wallet.personalID)
    }

    @Test("RecurringTemplate supports all recurrence patterns")
    func testAllPatterns() {
        let patterns: [RecurrencePattern] = [.daily, .weekly, .monthly, .yearly]

        for pattern in patterns {
            let template = RecurringTemplate(
                amount: 100,
                note: "Test \(pattern.rawValue)",
                categoryId: "other_expense",
                type: .expense,
                pattern: pattern,
                startDate: Date()
            )
            #expect(template.pattern == pattern)
        }
    }

    @Test("RecurringTemplate with end date")
    func testWithEndDate() {
        let start = Date()
        let end = Calendar.current.date(byAdding: .year, value: 1, to: start)!

        let template = RecurringTemplate(
            amount: 200000,
            note: "Gym membership",
            categoryId: "health",
            type: .expense,
            pattern: .monthly,
            startDate: start,
            endDate: end
        )

        #expect(template.endDate == end)
    }

    @Test("RecurringTemplate supports income type")
    func testIncomeTemplate() {
        let template = RecurringTemplate(
            amount: 15000000,
            note: "Monthly salary",
            categoryId: "salary",
            type: .income,
            pattern: .monthly,
            startDate: Date()
        )

        #expect(template.type == .income)
    }

    @Test("RecurringTemplate stores custom wallet ID")
    func testCustomWalletId() {
        let template = RecurringTemplate(
            amount: 15000000,
            note: "Monthly retainer",
            categoryId: "salary",
            walletId: "wallet_side_work",
            type: .income,
            pattern: .monthly,
            startDate: Date()
        )

        #expect(template.walletId == "wallet_side_work")
    }

    @Test("New recurring form starts with the resolved default wallet")
    @MainActor
    func recurringFormUsesDefaultWallet() {
        let wallets = [Wallet.personal(), Wallet(
            id: "wallet_side_work", name: "Side Work",
            iconName: "briefcase.fill", colorHex: "#2563EB"
        )]

        #expect(RecurringFormView.resolveInitialWalletId(
            existingTemplate: nil,
            wallets: wallets,
            defaultWalletId: "wallet_side_work"
        ) == "wallet_side_work")
    }

    @Test("Editing recurring form keeps an active assigned wallet")
    @MainActor
    func recurringFormKeepsExistingWallet() {
        let personal = Wallet.personal()
        let sideWork = Wallet(
            id: "wallet_side_work", name: "Side Work",
            iconName: "briefcase.fill", colorHex: "#2563EB"
        )
        let template = RecurringTemplate(
            amount: 100, note: "Tools", categoryId: "tools",
            walletId: "wallet_side_work"
        )

        #expect(RecurringFormView.resolveInitialWalletId(
            existingTemplate: template,
            wallets: [personal, sideWork],
            defaultWalletId: Wallet.personalID
        ) == "wallet_side_work")

        sideWork.isArchived = true

        #expect(RecurringFormView.resolveInitialWalletId(
            existingTemplate: template,
            wallets: [personal, sideWork],
            defaultWalletId: Wallet.personalID
        ) == Wallet.personalID)
    }
}
