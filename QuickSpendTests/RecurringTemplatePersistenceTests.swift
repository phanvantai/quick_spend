import Foundation
import SwiftData
import Testing
@testable import QuickSpend

@Suite("Recurring Template Persistence Tests")
@MainActor
struct RecurringTemplatePersistenceTests {
    private enum ExpectedSaveError: Error {
        case failed
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: RecurringTemplate.self,
            configurations: configuration
        )
    }

    private func makeOnDiskContainer(at storeURL: URL) throws -> ModelContainer {
        try ModelContainer(
            for: AppSchema.schema,
            migrationPlan: QuickSpendMigrationPlan.self,
            configurations: ModelConfiguration(
                "RecurringPersistence",
                schema: AppSchema.schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
        )
    }

    private func withTemporaryStore(
        _ operation: (URL) throws -> Void
    ) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuickSpendRecurring-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try operation(directory.appendingPathComponent("QuickSpend.sqlite"))
    }

    @Test("Create saves wallet ID durably across container reopen")
    func createPersistsWalletAcrossReopen() throws {
        try withTemporaryStore { storeURL in
            @MainActor func createAndClose() throws {
                let container = try makeOnDiskContainer(at: storeURL)
                let template = RecurringTemplate(
                    id: "recurring_create",
                    amount: 125,
                    note: "Side-work tools",
                    categoryId: "tools",
                    walletId: "wallet_side_work"
                )

                try RecurringTemplatePersistence.create(
                    template,
                    in: container.mainContext
                )
            }

            try createAndClose()

            let reopened = try makeOnDiskContainer(at: storeURL)
            let templates = try reopened.mainContext.fetch(FetchDescriptor<RecurringTemplate>())
            #expect(templates.count == 1)
            #expect(templates.first?.id == "recurring_create")
            #expect(templates.first?.walletId == "wallet_side_work")
        }
    }

    @Test("Edit saves wallet ID durably without rewriting historical transactions")
    func editPersistsWalletAcrossReopenWithoutRewritingTransactions() throws {
        try withTemporaryStore { storeURL in
            @MainActor func seedAndClose() throws {
                let container = try makeOnDiskContainer(at: storeURL)
                let context = container.mainContext
                context.insert(RecurringTemplate(
                    id: "recurring_edit",
                    amount: 500,
                    note: "Rent",
                    categoryId: "housing",
                    walletId: Wallet.personalID
                ))
                context.insert(Transaction(
                    id: "historical_generated",
                    amount: 500,
                    note: "Rent",
                    categoryId: "housing",
                    walletId: Wallet.personalID,
                    type: .expense
                ))
                try context.save()
            }

            @MainActor func editAndClose() throws {
                let container = try makeOnDiskContainer(at: storeURL)
                let context = container.mainContext
                let existing = try #require(
                    context.fetch(FetchDescriptor<RecurringTemplate>()).first
                )
                let updated = RecurringTemplate(
                    id: existing.id,
                    amount: existing.amount,
                    note: existing.note,
                    categoryId: existing.categoryId,
                    walletId: "wallet_side_work",
                    type: existing.type,
                    pattern: existing.pattern,
                    startDate: existing.startDate,
                    endDate: existing.endDate,
                    lastGeneratedDate: existing.lastGeneratedDate,
                    isActive: existing.isActive
                )

                try RecurringTemplatePersistence.update(
                    existing,
                    with: updated,
                    in: context
                )
            }

            try seedAndClose()
            try editAndClose()

            let reopened = try makeOnDiskContainer(at: storeURL)
            let context = reopened.mainContext
            let template = try #require(
                context.fetch(FetchDescriptor<RecurringTemplate>()).first
            )
            let transaction = try #require(
                context.fetch(FetchDescriptor<Transaction>()).first
            )
            #expect(template.walletId == "wallet_side_work")
            #expect(transaction.id == "historical_generated")
            #expect(transaction.walletId == Wallet.personalID)
        }
    }

    @Test("Create failure removes the inserted template")
    func createFailureRemovesInsertedTemplate() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let template = RecurringTemplate(
            id: "recurring_failed_create",
            amount: 125,
            note: "Tools",
            categoryId: "tools",
            walletId: "wallet_side_work"
        )

        #expect(throws: ExpectedSaveError.self) {
            try RecurringTemplatePersistence.create(
                template,
                in: context,
                save: { _ in throw ExpectedSaveError.failed }
            )
        }

        #expect(try context.fetch(FetchDescriptor<RecurringTemplate>()).isEmpty)
        #expect(context.insertedModelsArray.compactMap { $0 as? RecurringTemplate }.isEmpty)
    }

    @Test("Edit failure restores every editable value")
    func editFailureRestoresPriorValues() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let originalStart = Date(timeIntervalSince1970: 1_700_000_000)
        let originalEnd = originalStart.addingTimeInterval(2_592_000)
        let originalUpdatedAt = originalStart.addingTimeInterval(60)
        let existing = RecurringTemplate(
            id: "recurring_failed_edit",
            amount: 500,
            note: "Rent",
            categoryId: "housing",
            walletId: Wallet.personalID,
            type: .expense,
            pattern: .monthly,
            startDate: originalStart,
            endDate: originalEnd,
            updatedAt: originalUpdatedAt
        )
        context.insert(existing)
        try context.save()
        let updated = RecurringTemplate(
            id: existing.id,
            amount: 750,
            note: "Consulting",
            categoryId: "salary",
            walletId: "wallet_side_work",
            type: .income,
            pattern: .weekly,
            startDate: originalStart.addingTimeInterval(86_400),
            endDate: nil,
            updatedAt: originalUpdatedAt.addingTimeInterval(120)
        )

        #expect(throws: ExpectedSaveError.self) {
            try RecurringTemplatePersistence.update(
                existing,
                with: updated,
                in: context,
                save: { _ in throw ExpectedSaveError.failed }
            )
        }

        #expect(existing.amount == 500)
        #expect(existing.note == "Rent")
        #expect(existing.categoryId == "housing")
        #expect(existing.walletId == Wallet.personalID)
        #expect(existing.type == .expense)
        #expect(existing.pattern == .monthly)
        #expect(existing.startDate == originalStart)
        #expect(existing.endDate == originalEnd)
        #expect(existing.updatedAt == originalUpdatedAt)
    }
}
