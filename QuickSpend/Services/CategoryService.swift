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

    /// Update category names and keywords to match a new language
    @MainActor
    static func updateCategoryNames(
        language: String,
        modelContext: ModelContext
    ) {
        let descriptor = FetchDescriptor<Category>()
        guard let categories = try? modelContext.fetch(descriptor) else { return }
        for category in categories {
            category.name = categoryName(for: category.id, language: language)
            category.keywords = categoryKeywords(for: category.id, language: language)
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
            CategoryDef(id: "salary", iconName: "wallet.bifold.fill", colorHex: "4CAF50", type: .income, group: .earned),
            CategoryDef(id: "freelance", iconName: "laptopcomputer", colorHex: "2196F3", type: .income, group: .earned),
            CategoryDef(id: "bonus", iconName: "star.fill", colorHex: "FFC107", type: .income, group: .earned),
            // Income - Passive
            CategoryDef(id: "investment_income", iconName: "chart.bar.fill", colorHex: "009688", type: .income, group: .passive),
            CategoryDef(id: "interest", iconName: "percent", colorHex: "00BCD4", type: .income, group: .passive),
            // Income - Received
            CategoryDef(id: "gift_received", iconName: "gift.fill", colorHex: "E91E63", type: .income, group: .received),
            CategoryDef(id: "refund", iconName: "arrow.uturn.backward.circle.fill", colorHex: "FF9800", type: .income, group: .received),
            // Income - Other
            CategoryDef(id: "other_income", iconName: "plus.circle.fill", colorHex: "9C27B0", type: .income, group: .other),
        ]

        return definitions.enumerated().map { index, def in
            Category(
                id: def.id,
                name: categoryName(for: def.id, language: language),
                iconName: def.iconName,
                colorHex: def.colorHex,
                type: def.type,
                group: def.group,
                keywords: categoryKeywords(for: def.id, language: language),
                sortOrder: index
            )
        }
    }

    /// Get localized category name for a given category ID and language
    static func categoryName(for id: String, language: String) -> String {
        let names: [String: [String: String]] = [
            // Expense categories
            "food_drink": ["en": "Food & Drink", "vi": "Ăn uống"],
            "groceries": ["en": "Groceries", "vi": "Đi chợ / Siêu thị"],
            "transport": ["en": "Transport", "vi": "Di chuyển"],
            "housing": ["en": "Housing", "vi": "Nhà ở"],
            "bills_utilities": ["en": "Bills & Utilities", "vi": "Hoá đơn"],
            "shopping": ["en": "Shopping", "vi": "Mua sắm"],
            "health": ["en": "Health", "vi": "Sức khoẻ"],
            "education": ["en": "Education", "vi": "Học tập"],
            "entertainment": ["en": "Entertainment", "vi": "Giải trí"],
            "personal_care": ["en": "Personal Care", "vi": "Chăm sóc cá nhân"],
            "gifts": ["en": "Gifts & Donations", "vi": "Quà tặng"],
            "family": ["en": "Family", "vi": "Gia đình"],
            "insurance": ["en": "Insurance", "vi": "Bảo hiểm"],
            "savings_invest": ["en": "Savings & Investment", "vi": "Tiết kiệm / Đầu tư"],
            "debt_payment": ["en": "Debt Payment", "vi": "Trả nợ"],
            "pets": ["en": "Pets", "vi": "Thú cưng"],
            "travel": ["en": "Travel", "vi": "Du lịch"],
            "other_expense": ["en": "Other", "vi": "Khác"],
            // Income categories
            "salary": ["en": "Salary", "vi": "Lương"],
            "freelance": ["en": "Freelance", "vi": "Thu nhập tự do"],
            "bonus": ["en": "Bonus", "vi": "Thưởng"],
            "investment_income": ["en": "Investment", "vi": "Thu nhập đầu tư"],
            "interest": ["en": "Interest", "vi": "Lãi suất"],
            "gift_received": ["en": "Gift Received", "vi": "Được tặng"],
            "refund": ["en": "Refund", "vi": "Hoàn tiền"],
            "other_income": ["en": "Other Income", "vi": "Thu nhập khác"],
        ]
        return names[id]?[language] ?? names[id]?["en"] ?? id
    }

    /// Get localized keywords for a given category ID and language
    static func categoryKeywords(for id: String, language: String) -> [String] {
        let keywords: [String: [String: [String]]] = [
            "food_drink": [
                "en": ["food", "eat", "lunch", "dinner", "breakfast", "coffee", "drink", "restaurant", "cafe", "pizza", "burger", "snack", "meal"],
                "vi": ["an", "com", "pho", "bun", "ca phe", "cafe", "tra", "nuoc", "uong", "sang", "trua", "toi", "quan", "nha hang", "an vat", "do an"],
            ],
            "groceries": [
                "en": ["groceries", "supermarket", "market", "vegetables", "fruit", "meat", "fish"],
                "vi": ["cho", "sieu thi", "rau", "thit", "ca", "trai cay", "do an", "nguyen lieu"],
            ],
            "transport": [
                "en": ["transport", "taxi", "uber", "grab", "bus", "train", "metro", "parking", "gas", "petrol", "fuel", "car", "bike", "toll"],
                "vi": ["xe", "taxi", "grab", "xang", "dau", "bus", "xe buyt", "tau", "metro", "do xe", "gui xe", "o to", "xe may", "di chuyen"],
            ],
            "housing": [
                "en": ["rent", "mortgage", "housing", "apartment", "room"],
                "vi": ["nha", "thue nha", "phong", "tien nha", "nha o"],
            ],
            "bills_utilities": [
                "en": ["bill", "electricity", "water", "internet", "phone", "utility", "subscription"],
                "vi": ["hoa don", "dien", "nuoc", "internet", "wifi", "dien thoai", "phi"],
            ],
            "shopping": [
                "en": ["shopping", "shop", "buy", "clothes", "shoes", "mall", "store", "electronics", "purchase"],
                "vi": ["mua", "shopping", "quan ao", "giay", "dep", "ao", "sieu thi", "do", "mua sam"],
            ],
            "health": [
                "en": ["health", "medicine", "doctor", "hospital", "pharmacy", "clinic", "medical", "gym", "fitness"],
                "vi": ["thuoc", "bac si", "benh vien", "kham", "y te", "suc khoe", "nha thuoc", "phong kham", "gym", "the duc"],
            ],
            "education": [
                "en": ["education", "school", "course", "book", "tuition", "class", "study", "learn", "training"],
                "vi": ["hoc", "truong", "khoa hoc", "sach", "hoc phi", "lop", "dao tao", "hoc tap"],
            ],
            "entertainment": [
                "en": ["entertainment", "movie", "cinema", "game", "music", "concert", "party", "fun", "hobby", "sport"],
                "vi": ["giai tri", "phim", "rap", "cinema", "game", "nhac", "ca nhac", "tiec", "vui choi", "the thao", "bong da"],
            ],
            "personal_care": [
                "en": ["personal care", "haircut", "spa", "beauty", "skincare", "cosmetics", "salon"],
                "vi": ["cham soc", "cat toc", "spa", "lam dep", "my pham", "da", "salon"],
            ],
            "gifts": [
                "en": ["gift", "present", "donation", "charity", "give"],
                "vi": ["qua", "qua tang", "tu thien", "tang", "bieu"],
            ],
            "family": [
                "en": ["family", "kids", "children", "baby", "parent", "support"],
                "vi": ["gia dinh", "con", "tre em", "bo me", "ho tro"],
            ],
            "insurance": [
                "en": ["insurance", "premium", "coverage", "policy"],
                "vi": ["bao hiem", "phi bao hiem"],
            ],
            "savings_invest": [
                "en": ["savings", "investment", "stock", "fund", "deposit"],
                "vi": ["tiet kiem", "dau tu", "co phieu", "gui tien", "quy"],
            ],
            "debt_payment": [
                "en": ["debt", "loan", "payment", "credit", "repay", "installment"],
                "vi": ["no", "tra no", "vay", "tin dung", "tra gop"],
            ],
            "pets": [
                "en": ["pet", "dog", "cat", "vet", "animal", "food pet"],
                "vi": ["thu cung", "cho", "meo", "thu y", "dong vat"],
            ],
            "travel": [
                "en": ["travel", "trip", "vacation", "hotel", "flight", "tour", "holiday"],
                "vi": ["du lich", "chuyen di", "khach san", "bay", "tour", "nghi"],
            ],
            "other_expense": [
                "en": ["other", "misc", "miscellaneous"],
                "vi": ["khac"],
            ],
            "salary": [
                "en": ["salary", "wage", "paycheck", "income", "pay", "work", "job", "earnings"],
                "vi": ["luong", "tien luong", "cong", "luong thang", "thu nhap", "tra luong", "nhan luong"],
            ],
            "freelance": [
                "en": ["freelance", "side job", "gig", "project", "contract", "part time", "extra income"],
                "vi": ["lam them", "freelance", "tu do", "du an", "hop dong", "part time", "lam ngoai", "thu nhap phu"],
            ],
            "bonus": [
                "en": ["bonus", "reward", "prize", "incentive"],
                "vi": ["thuong", "giai thuong", "phan thuong", "khen thuong"],
            ],
            "investment_income": [
                "en": ["investment", "dividend", "stock", "profit", "return", "capital gain"],
                "vi": ["dau tu", "co tuc", "co phieu", "loi nhuan", "sinh loi", "chung khoan"],
            ],
            "interest": [
                "en": ["interest", "bank interest", "savings interest"],
                "vi": ["lai", "tien lai", "lai suat", "lai ngan hang"],
            ],
            "gift_received": [
                "en": ["gift", "present", "lucky money", "red envelope", "allowance"],
                "vi": ["qua", "qua tang", "li xi", "tien mung", "tien li xi"],
            ],
            "refund": [
                "en": ["refund", "return", "reimbursement", "cashback", "payback"],
                "vi": ["hoan tien", "hoan lai", "tra lai", "cashback", "hoan"],
            ],
            "other_income": [
                "en": ["other income", "miscellaneous income", "extra"],
                "vi": ["thu nhap khac", "thu khac"],
            ],
        ]
        return keywords[id]?[language] ?? keywords[id]?["en"] ?? [id]
    }
}
