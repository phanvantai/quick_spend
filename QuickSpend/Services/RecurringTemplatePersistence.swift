import Foundation
import SwiftData

@MainActor
enum RecurringTemplatePersistence {
    typealias SaveOperation = (ModelContext) throws -> Void

    static func create(
        _ template: RecurringTemplate,
        in modelContext: ModelContext,
        save: SaveOperation = { try $0.save() }
    ) throws {
        modelContext.insert(template)
        do {
            try save(modelContext)
        } catch {
            modelContext.delete(template)
            modelContext.processPendingChanges()
            throw error
        }
    }

    static func update(
        _ template: RecurringTemplate,
        with updated: RecurringTemplate,
        in modelContext: ModelContext,
        save: SaveOperation = { try $0.save() }
    ) throws {
        let priorValues = EditableValues(template)
        EditableValues(updated).apply(to: template)

        do {
            try save(modelContext)
        } catch {
            priorValues.apply(to: template)
            modelContext.processPendingChanges()
            throw error
        }
    }

    private struct EditableValues {
        let amount: Double
        let note: String
        let categoryId: String
        let walletId: String
        let type: TransactionType
        let pattern: RecurrencePattern
        let startDate: Date
        let endDate: Date?
        let updatedAt: Date

        init(_ template: RecurringTemplate) {
            amount = template.amount
            note = template.note
            categoryId = template.categoryId
            walletId = template.walletId
            type = template.type
            pattern = template.pattern
            startDate = template.startDate
            endDate = template.endDate
            updatedAt = template.updatedAt
        }

        func apply(to template: RecurringTemplate) {
            template.amount = amount
            template.note = note
            template.categoryId = categoryId
            template.walletId = walletId
            template.type = type
            template.pattern = pattern
            template.startDate = startDate
            template.endDate = endDate
            template.updatedAt = updatedAt
        }
    }
}
