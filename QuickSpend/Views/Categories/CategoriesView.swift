import SwiftUI
import SwiftData

/// Category management screen with system and user categories
struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigViewModel.self) private var appConfig
    @Query(sort: \QuickCategory.name) private var allCategories: [QuickCategory]

    @State private var showIncome = false
    @State private var showingAddCategory = false
    @State private var editingCategory: QuickCategory?
    @State private var deletingCategory: QuickCategory?

    private var filteredCategories: [QuickCategory] {
        allCategories.filter { showIncome ? $0.isIncomeCategory : $0.isExpenseCategory }
    }

    private var systemCategories: [QuickCategory] {
        filteredCategories.filter(\.isSystem)
    }

    private var userCategories: [QuickCategory] {
        filteredCategories.filter { !$0.isSystem }
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

            // System categories
            Section {
                ForEach(systemCategories, id: \.id) { category in
                    categoryRow(category, isSystem: true)
                }
            } header: {
                Text("System Categories")
            } footer: {
                Text("System categories can be edited but not deleted.")
            }

            // User categories
            Section {
                if userCategories.isEmpty {
                    ContentUnavailableView(
                        "No Custom Categories",
                        systemImage: "square.grid.2x2",
                        description: Text("Tap + to create a custom category.")
                    )
                } else {
                    ForEach(userCategories, id: \.id) { category in
                        categoryRow(category, isSystem: false)
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
            } header: {
                Text("Custom Categories")
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
                category.typeRawValue = updated.typeRawValue
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
                Text("Delete \"\(category.name)\"? Expenses using this category will be reassigned to \"Other\".")
            }
        }
    }

    // MARK: - Category Row

    private func categoryRow(_ category: QuickCategory, isSystem: Bool) -> some View {
        let isFallback = category.id == "other" || category.id == "other_income"

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
            } else if isSystem {
                Button {
                    editingCategory = category
                } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func deleteCategory(_ category: QuickCategory) {
        // Reassign expenses to "other" or "other_income"
        let fallbackId = category.isIncomeCategory ? "other_income" : "other"
        CategoryService.reassignExpenses(
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
    .modelContainer(for: [Expense.self, QuickCategory.self, RecurringTemplate.self], inMemory: true)
    .environment(AppConfigViewModel())
}
