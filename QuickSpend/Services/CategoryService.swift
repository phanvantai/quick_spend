import Foundation
import SwiftData

/// Service for managing categories using SwiftData
struct CategoryService {

    /// Seed default categories if none exist
    /// Should be called once after onboarding is complete
    @MainActor
    static func seedCategoriesIfNeeded(
        language: String,
        modelContext: ModelContext
    ) {
        let descriptor = FetchDescriptor<Category>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0

        guard existingCount == 0 else {
            print("[CategoryService] Categories already exist (\(existingCount)), skipping seed")
            return
        }

        print("[CategoryService] Seeding categories for language: \(language)")
        let categories = defaultCategories(language: language)
        for category in categories {
            modelContext.insert(category)
        }
        print("[CategoryService] Seeded \(categories.count) categories")
    }

    /// Update category names to match a new language
    @MainActor
    static func updateCategoryNames(
        language: String,
        modelContext: ModelContext
    ) {
        let descriptor = FetchDescriptor<Category>()
        guard let categories = try? modelContext.fetch(descriptor) else { return }
        for category in categories {
            category.name = categoryName(for: category.id, language: language)
            category.updatedAt = .now
        }
        print("[CategoryService] Updated \(categories.count) categories to language: \(language)")
    }

    /// Reassign all transactions from one category to another
    @MainActor
    static func reassignTransactions(
        from fromCategoryId: String,
        to toCategoryId: String,
        modelContext: ModelContext
    ) {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.categoryId == fromCategoryId }
        )
        guard let transactions = try? modelContext.fetch(descriptor) else { return }
        for transaction in transactions {
            transaction.categoryId = toCategoryId
            transaction.updatedAt = .now
        }
    }

    // MARK: - Default Category Data

    /// Get all default categories for a given language
    static func defaultCategories(language: String) -> [Category] {
        struct CategoryDef {
            let id: String
            let iconName: String
            let colorHex: String
            let type: TransactionType
            let group: CategoryGroup
        }

        let definitions: [CategoryDef] = [
            // Expense - Daily Living
            CategoryDef(id: "food_drink", iconName: "fork.knife", colorHex: "FF8C42", type: .expense, group: .dailyLiving),
            CategoryDef(id: "groceries", iconName: "cart.fill", colorHex: "8BC34A", type: .expense, group: .dailyLiving),
            CategoryDef(id: "transport", iconName: "car.fill", colorHex: "5F5CF1", type: .expense, group: .dailyLiving),
            CategoryDef(id: "housing", iconName: "house.fill", colorHex: "795548", type: .expense, group: .dailyLiving),
            CategoryDef(id: "bills_utilities", iconName: "bolt.fill", colorHex: "FF5757", type: .expense, group: .dailyLiving),
            // Expense - Personal
            CategoryDef(id: "shopping", iconName: "bag.fill", colorHex: "6C5CE7", type: .expense, group: .personal),
            CategoryDef(id: "health", iconName: "cross.case.fill", colorHex: "4CAF50", type: .expense, group: .personal),
            CategoryDef(id: "education", iconName: "book.fill", colorHex: "3F51B5", type: .expense, group: .personal),
            CategoryDef(id: "entertainment", iconName: "film.fill", colorHex: "FF6B9D", type: .expense, group: .personal),
            CategoryDef(id: "personal_care", iconName: "sparkles", colorHex: "E91E63", type: .expense, group: .personal),
            // Expense - Social
            CategoryDef(id: "gifts", iconName: "gift.fill", colorHex: "9C27B0", type: .expense, group: .social),
            CategoryDef(id: "family", iconName: "person.2.fill", colorHex: "00BCD4", type: .expense, group: .social),
            // Expense - Financial
            CategoryDef(id: "insurance", iconName: "shield.fill", colorHex: "607D8B", type: .expense, group: .financial),
            CategoryDef(id: "savings_invest", iconName: "chart.line.uptrend.xyaxis", colorHex: "009688", type: .expense, group: .financial),
            CategoryDef(id: "debt_payment", iconName: "creditcard.fill", colorHex: "F44336", type: .expense, group: .financial),
            // Expense - Other
            CategoryDef(id: "pets", iconName: "pawprint.fill", colorHex: "8D6E63", type: .expense, group: .other),
            CategoryDef(id: "travel", iconName: "airplane", colorHex: "00ACC1", type: .expense, group: .other),
            CategoryDef(id: "other_expense", iconName: "ellipsis.circle.fill", colorHex: "9E9EB5", type: .expense, group: .other),
            // Income - Earned
            CategoryDef(id: "salary", iconName: "wallet.bifold.fill", colorHex: "2E7D32", type: .income, group: .earned),
            CategoryDef(id: "freelance", iconName: "laptopcomputer", colorHex: "2196F3", type: .income, group: .earned),
            CategoryDef(id: "bonus", iconName: "star.fill", colorHex: "FFC107", type: .income, group: .earned),
            // Income - Passive
            CategoryDef(id: "investment_income", iconName: "chart.bar.fill", colorHex: "26A69A", type: .income, group: .passive),
            CategoryDef(id: "interest", iconName: "percent", colorHex: "0288D1", type: .income, group: .passive),
            // Income - Received
            CategoryDef(id: "gift_received", iconName: "gift.fill", colorHex: "F06292", type: .income, group: .received),
            CategoryDef(id: "refund", iconName: "arrow.uturn.backward.circle.fill", colorHex: "FF9800", type: .income, group: .received),
            // Income - Other
            CategoryDef(id: "other_income", iconName: "plus.circle.fill", colorHex: "7B1FA2", type: .income, group: .other),
        ]

        return definitions.enumerated().map { index, def in
            Category(
                id: def.id,
                name: categoryName(for: def.id, language: language),
                iconName: def.iconName,
                colorHex: def.colorHex,
                type: def.type,
                group: def.group,
                sortOrder: index
            )
        }
    }

    /// Get localized category name for a given category ID and language
    static func categoryName(for id: String, language: String) -> String {
        let names: [String: [String: String]] = [
            // Expense categories
            "food_drink": ["en": "Food & Drink", "vi": "Ăn uống", "ja": "飲食", "es": "Comida y bebida"],
            "groceries": ["en": "Groceries", "vi": "Đi chợ / Siêu thị", "ja": "食料品", "es": "Supermercado"],
            "transport": ["en": "Transport", "vi": "Di chuyển", "ja": "交通", "es": "Transporte"],
            "housing": ["en": "Housing", "vi": "Nhà ở", "ja": "住居", "es": "Vivienda"],
            "bills_utilities": ["en": "Bills & Utilities", "vi": "Hoá đơn", "ja": "光熱費", "es": "Facturas"],
            "shopping": ["en": "Shopping", "vi": "Mua sắm", "ja": "買い物", "es": "Compras"],
            "health": ["en": "Health", "vi": "Sức khoẻ", "ja": "健康", "es": "Salud"],
            "education": ["en": "Education", "vi": "Học tập", "ja": "教育", "es": "Educación"],
            "entertainment": ["en": "Entertainment", "vi": "Giải trí", "ja": "娯楽", "es": "Entretenimiento"],
            "personal_care": ["en": "Personal Care", "vi": "Chăm sóc cá nhân", "ja": "美容・身だしなみ", "es": "Cuidado personal"],
            "gifts": ["en": "Gifts & Donations", "vi": "Quà tặng", "ja": "贈り物・寄付", "es": "Regalos y donaciones"],
            "family": ["en": "Family", "vi": "Gia đình", "ja": "家族", "es": "Familia"],
            "insurance": ["en": "Insurance", "vi": "Bảo hiểm", "ja": "保険", "es": "Seguros"],
            "savings_invest": ["en": "Savings & Investment", "vi": "Tiết kiệm / Đầu tư", "ja": "貯蓄・投資", "es": "Ahorro e inversión"],
            "debt_payment": ["en": "Debt Payment", "vi": "Trả nợ", "ja": "借金返済", "es": "Pago de deudas"],
            "pets": ["en": "Pets", "vi": "Thú cưng", "ja": "ペット", "es": "Mascotas"],
            "travel": ["en": "Travel", "vi": "Du lịch", "ja": "旅行", "es": "Viajes"],
            "other_expense": ["en": "Other", "vi": "Khác", "ja": "その他", "es": "Otros"],
            // Income categories
            "salary": ["en": "Salary", "vi": "Lương", "ja": "給料", "es": "Salario"],
            "freelance": ["en": "Freelance", "vi": "Thu nhập tự do", "ja": "フリーランス", "es": "Freelance"],
            "bonus": ["en": "Bonus", "vi": "Thưởng", "ja": "ボーナス", "es": "Bonificación"],
            "investment_income": ["en": "Investment", "vi": "Thu nhập đầu tư", "ja": "投資収入", "es": "Inversiones"],
            "interest": ["en": "Interest", "vi": "Lãi suất", "ja": "利息", "es": "Intereses"],
            "gift_received": ["en": "Gift Received", "vi": "Được tặng", "ja": "受け取ったギフト", "es": "Regalos recibidos"],
            "refund": ["en": "Refund", "vi": "Hoàn tiền", "ja": "払い戻し", "es": "Reembolso"],
            "other_income": ["en": "Other Income", "vi": "Thu nhập khác", "ja": "その他の収入", "es": "Otros ingresos"],
        ]
        return names[id]?[language] ?? names[id]?["en"] ?? id
    }

}
