import Foundation

/// Statistics for a single expense category (computed, not persisted)
struct CategoryStats: Identifiable {
    let categoryId: String
    let categoryName: String
    let totalAmount: Double
    let count: Int
    let percentage: Double
    let colorHex: String
    let iconName: String
    let type: TransactionType

    var id: String { categoryId }

    var isIncomeCategory: Bool { type == .income }
    var isExpenseCategory: Bool { type == .expense }
}
