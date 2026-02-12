import Foundation

/// Transaction type for expenses and income
enum TransactionType: String, Codable, CaseIterable {
    case expense
    case income
}
