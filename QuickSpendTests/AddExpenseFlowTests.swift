import Testing
import Foundation
import SwiftData
@testable import QuickSpend

private typealias AppCategory = QuickSpend.Category

@MainActor
private final class MockExpenseParser: ExpenseParsing {
    var stubbedResults: [ParsedTransaction] = []
    var capturedInput: String?
    var capturedLanguage: String?
    var capturedCurrency: String?
    var capturedCategoryCount: Int?
    var callCount = 0

    func parse(
        input: String,
        categories: [QuickSpend.Category],
        language: String,
        currency: String,
        usageLimitService: UsageLimitService
    ) async -> [ParsedTransaction] {
        callCount += 1
        capturedInput = input
        capturedLanguage = language
        capturedCurrency = currency
        capturedCategoryCount = categories.count
        return stubbedResults
    }
}

@Suite("AddExpenseFlow Tests")
@MainActor
struct AddExpenseFlowTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Transaction.self, AppCategory.self, RecurringTemplate.self, BalanceAnchor.self,
            Wallet.self, BalanceAdjustment.self,
            configurations: config
        )
    }

    private func makeUsage(suiteName: String = UUID().uuidString) -> UsageLimitService {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return UsageLimitService(defaults: defaults)
    }

    private func seedCategories(in context: ModelContext) {
        CategoryService.seedCategoriesIfNeeded(language: "en", modelContext: context)
        try? context.save()
    }

    // MARK: - parse

    @Test("parse returns parser results when limit not reached and categories exist")
    func parseHappyPath() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedCategories(in: context)

        let parser = MockExpenseParser()
        parser.stubbedResults = [
            ParsedTransaction(
                amount: 4.50, note: "Coffee", categoryId: "food_drink",
                type: .expense, date: .now, confidence: 0.9
            )
        ]
        let usage = makeUsage()

        let results = try await AddExpenseFlow.parse(
            input: "coffee 4.50",
            in: context,
            language: "en",
            currency: "USD",
            parser: parser,
            usage: usage
        )

        #expect(results.count == 1)
        #expect(results[0].note == "Coffee")
        #expect(parser.callCount == 1)
        #expect(parser.capturedInput == "coffee 4.50")
        #expect(parser.capturedLanguage == "en")
        #expect(parser.capturedCurrency == "USD")
        #expect((parser.capturedCategoryCount ?? 0) > 0)
    }

    @Test("parse throws limitReached when usage limit hit, parser not called")
    func parseLimitReached() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedCategories(in: context)

        let parser = MockExpenseParser()
        let usage = makeUsage()
        // Push usage past the free-tier limit
        for _ in 0..<AppConstants.freeTierGeminiLimit {
            usage.incrementUsage()
        }
        #expect(usage.canParse == false)

        await #expect(throws: AddExpenseError.self) {
            _ = try await AddExpenseFlow.parse(
                input: "coffee 4.50",
                in: context,
                language: "en",
                currency: "USD",
                parser: parser,
                usage: usage
            )
        }
        #expect(parser.callCount == 0)
    }

    @Test("parse throws couldNotParse when parser returns empty")
    func parseEmptyResults() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedCategories(in: context)

        let parser = MockExpenseParser()
        parser.stubbedResults = []
        let usage = makeUsage()

        await #expect(throws: AddExpenseError.self) {
            _ = try await AddExpenseFlow.parse(
                input: "uh",
                in: context,
                language: "en",
                currency: "USD",
                parser: parser,
                usage: usage
            )
        }
    }

    @Test("parse throws noCategories when store has no categories")
    func parseNoCategories() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        // Deliberately do not seed categories

        let parser = MockExpenseParser()
        parser.stubbedResults = [
            ParsedTransaction(amount: 1, note: "x", categoryId: "food_drink", type: .expense, date: .now, confidence: 1)
        ]
        let usage = makeUsage()

        await #expect(throws: AddExpenseError.self) {
            _ = try await AddExpenseFlow.parse(
                input: "coffee 4.50",
                in: context,
                language: "en",
                currency: "USD",
                parser: parser,
                usage: usage
            )
        }
        #expect(parser.callCount == 0)
    }

    // MARK: - save

    @Test("save inserts each parsed transaction and persists them")
    func saveInsertsAll() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let parsed: [ParsedTransaction] = [
            ParsedTransaction(amount: 4.50, note: "Coffee", categoryId: "food_drink", type: .expense, date: .now, confidence: 0.9),
            ParsedTransaction(amount: 12.0, note: "Lunch", categoryId: "food_drink", type: .expense, date: .now, confidence: 0.8),
        ]

        let saved = try AddExpenseFlow.save(parsed: parsed, rawInput: "coffee 4.50, lunch 12", in: context)

        #expect(saved.count == 2)
        let stored = try context.fetch(FetchDescriptor<Transaction>())
        #expect(stored.count == 2)
        let notes = Set(stored.map(\.note))
        #expect(notes == ["Coffee", "Lunch"])
        #expect(stored.allSatisfy { $0.rawInput == "coffee 4.50, lunch 12" })
        #expect(stored.allSatisfy { ($0.confidence ?? 0) > 0 })
    }

    @Test("save preserves parsed date, type, categoryId verbatim")
    func savePreservesFields() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let specificDate = Date(timeIntervalSince1970: 1_700_000_000)
        let parsed: [ParsedTransaction] = [
            ParsedTransaction(amount: 1500, note: "Salary", categoryId: "salary", type: .income, date: specificDate, confidence: 1.0),
        ]

        try AddExpenseFlow.save(parsed: parsed, rawInput: "got salary", in: context)

        let stored = try context.fetch(FetchDescriptor<Transaction>())
        #expect(stored.count == 1)
        #expect(stored[0].categoryId == "salary")
        #expect(stored[0].type == .income)
        #expect(stored[0].date == specificDate)
        #expect(stored[0].amount == 1500)
    }

    @Test("save with empty array inserts nothing")
    func saveEmpty() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let saved = try AddExpenseFlow.save(parsed: [], rawInput: "x", in: context)
        #expect(saved.isEmpty)
        let stored = try context.fetch(FetchDescriptor<Transaction>())
        #expect(stored.isEmpty)
    }

    @Test("Siri save affects balance even when device time is before the wallet anchor")
    func saveBeforeAnchorCreatesCompensatingAdjustment() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(BalanceAnchor(
            openingBalance: 1_000,
            anchorDate: Date.now.addingTimeInterval(3_600)
        ))
        try context.save()

        _ = try AddExpenseFlow.save(
            parsed: [ParsedTransaction(
                amount: 100, note: "Coffee", categoryId: "food_drink",
                type: .expense, date: .now, confidence: 1
            )],
            rawInput: "coffee 100",
            in: context
        )

        let balance = BalanceService(modelContext: context, autoObserve: false, autoCompute: false)
        #expect(try balance.computeBalance() == 900)
        #expect(try context.fetchCount(FetchDescriptor<BalanceAdjustment>()) == 1)
    }
}
