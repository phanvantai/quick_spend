import Foundation
import SwiftData

/// Core transaction model for both expenses and income
@Model
final class Transaction {
    @Attribute(.unique) var id: String
    var amount: Double
    var note: String
    var categoryId: String
    var type: TransactionType
    var date: Date
    var rawInput: String?
    var confidence: Double?
    var createdAt: Date
    var updatedAt: Date

    var isIncome: Bool { type == .income }
    var isExpense: Bool { type == .expense }

    init(
        id: String = UUID().uuidString,
        amount: Double,
        note: String,
        categoryId: String,
        type: TransactionType = .expense,
        date: Date = .now,
        rawInput: String? = nil,
        confidence: Double? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.note = note
        self.categoryId = categoryId
        self.type = type
        self.date = date
        self.rawInput = rawInput
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
