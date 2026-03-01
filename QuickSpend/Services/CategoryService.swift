import Foundation
import SwiftData

/// Service for managing categories using SwiftData
struct CategoryService {

    /// Seed default system categories if none exist
    /// Should be called once after onboarding is complete
    @MainActor
    static func seedSystemCategoriesIfNeeded(
        language: String,
        modelContext: ModelContext
    ) {
        let descriptor = FetchDescriptor<QuickCategory>(
            predicate: #Predicate { $0.isSystem == true }
        )
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0

        guard existingCount == 0 else {
            print("[CategoryService] System categories already exist (\(existingCount)), skipping seed")
            return
        }

        print("[CategoryService] Seeding system categories for language: \(language)")
        let categories = QuickCategory.defaultSystemCategories(language: language)
        for category in categories {
            modelContext.insert(category)
        }
        print("[CategoryService] Seeded \(categories.count) categories")
    }

    /// Update system category names and keywords to match a new language
    @MainActor
    static func updateSystemCategoryNames(
        language: String,
        modelContext: ModelContext
    ) {
        let descriptor = FetchDescriptor<QuickCategory>(
            predicate: #Predicate { $0.isSystem == true }
        )
        guard let categories = try? modelContext.fetch(descriptor) else { return }
        for category in categories {
            category.name = QuickCategory.categoryName(for: category.id, language: language)
            category.keywords = QuickCategory.categoryKeywords(for: category.id, language: language)
        }
        print("[CategoryService] Updated \(categories.count) system categories to language: \(language)")
    }

    /// Reassign all expenses from one category to another
    @MainActor
    static func reassignExpenses(
        from fromCategoryId: String,
        to toCategoryId: String,
        modelContext: ModelContext
    ) {
        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { $0.categoryId == fromCategoryId }
        )
        guard let expenses = try? modelContext.fetch(descriptor) else { return }
        for expense in expenses {
            expense.categoryId = toCategoryId
        }
    }
}
