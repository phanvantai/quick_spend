import SwiftUI
import SwiftData

/// Category management screen
struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]

    @State private var showIncome = false
    @State private var showingAddCategory = false
    @State private var editingCategory: Category?
    @State private var deletingCategory: Category?

    private var filteredCategories: [Category] {
        allCategories.filter { !$0.isHidden && (showIncome ? $0.isIncomeCategory : $0.isExpenseCategory) }
    }

    var body: some View {
        List {
            // Type filter
            Section {
                Picker("Type", selection: $showIncome) {
                    Text("Expense").tag(false)
                    Text("Income").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, AppTheme.spacing4)
            }

            // Categories
            Section {
                if filteredCategories.isEmpty {
                    ContentUnavailableView(
                        "No Categories",
                        systemImage: "square.grid.2x2",
                        description: Text("Tap + to create a category.")
                    )
                } else {
                    ForEach(filteredCategories, id: \.id) { category in
                        categoryRow(category)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deletingCategory = category
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    editingCategory = category
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(AppTheme.primaryMint)
                            }
                    }
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddCategory = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            CategoryFormView(defaultType: showIncome ? .income : .expense) { newCategory in
                modelContext.insert(newCategory)
            }
        }
        .sheet(item: $editingCategory) { category in
            CategoryFormView(existingCategory: category) { updated in
                category.name = updated.name
                category.keywords = updated.keywords
                category.iconName = updated.iconName
                category.colorHex = updated.colorHex
                category.type = updated.type
                category.updatedAt = .now
            }
        }
        .alert("Delete Category", isPresented: .init(
            get: { deletingCategory != nil },
            set: { if !$0 { deletingCategory = nil } }
        )) {
            Button("Cancel", role: .cancel) { deletingCategory = nil }
            Button("Delete", role: .destructive) {
                if let category = deletingCategory {
                    deleteCategory(category)
                }
            }
        } message: {
            if let category = deletingCategory {
                Text("Delete \"\(category.name)\"? Transactions using this category will be reassigned to \"Other\".")
            }
        }
    }

    // MARK: - Category Row

    private func categoryRow(_ category: Category) -> some View {
        let isFallback = category.id == "other_expense" || category.id == "other_income"

        return HStack(spacing: AppTheme.spacing12) {
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                .fill(category.color.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: category.iconName)
                        .foregroundStyle(category.color)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.body)
                if isFallback {
                    Text("Required category")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !category.keywords.isEmpty {
                    Text(category.keywords.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isFallback {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func deleteCategory(_ category: Category) {
        // Reassign transactions to "other_expense" or "other_income"
        let fallbackId = category.isIncomeCategory ? "other_income" : "other_expense"
        CategoryService.reassignTransactions(
            from: category.id,
            to: fallbackId,
            modelContext: modelContext
        )
        modelContext.delete(category)
        deletingCategory = nil
    }
}

#Preview {
    NavigationStack {
        CategoriesView()
    }
    .modelContainer(for: [Transaction.self, Category.self, RecurringTemplate.self], inMemory: true)
    .environment(AppConfigViewModel())
}
