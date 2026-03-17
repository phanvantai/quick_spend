import Foundation
import SwiftUI
import SwiftData

/// Category model for organizing transactions
@Model
final class Category {
    var id: String = ""
    var name: String = ""
    var iconName: String = ""
    var colorHex: String = "#000000"
    var type: TransactionType = TransactionType.expense
    var group: CategoryGroup?
    var sortOrder: Int = 0
    var isHidden: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    /// Resolved SwiftUI Color from hex string
    var color: Color {
        Color(hex: colorHex)
    }

    var isIncomeCategory: Bool { type == .income }
    var isExpenseCategory: Bool { type == .expense }

    init(
        id: String,
        name: String,
        iconName: String,
        colorHex: String,
        type: TransactionType,
        group: CategoryGroup? = nil,
        sortOrder: Int = 0,
        isHidden: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.type = type
        self.group = group
        self.sortOrder = sortOrder
        self.isHidden = isHidden
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
