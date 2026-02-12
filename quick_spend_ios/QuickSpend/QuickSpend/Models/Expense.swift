import Foundation
import SwiftData

/// Core expense/income transaction model
@Model
final class Expense {
    @Attribute(.unique) var id: String
    var amount: Double
    var descriptionText: String
    var categoryId: String
    var language: String
    var date: Date
    var userId: String
    var rawInput: String
    var confidence: Double
    var typeRawValue: String

    /// Transaction type (expense or income)
    var type: TransactionType {
        get { TransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }

    var isIncome: Bool { type == .income }
    var isExpense: Bool { type == .expense }

    init(
        id: String = UUID().uuidString,
        amount: Double,
        descriptionText: String,
        categoryId: String,
        language: String = "en",
        date: Date = .now,
        userId: String = AppConstants.defaultUserId,
        rawInput: String = "",
        confidence: Double = 1.0,
        type: TransactionType = .expense
    ) {
        self.id = id
        self.amount = amount
        self.descriptionText = descriptionText
        self.categoryId = categoryId
        self.language = language
        self.date = date
        self.userId = userId
        self.rawInput = rawInput
        self.confidence = confidence
        self.typeRawValue = type.rawValue
    }
}
