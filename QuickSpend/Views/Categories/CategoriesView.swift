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
                Picker(L10n.tr("common.type", appConfig.language), selection: $showIncome) {
                    Text(L10n.tr("common.expense", appConfig.language)).tag(false)
                    Text(L10n.tr("common.income", appConfig.language)).tag(true)
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
                        L10n.tr("categories.no_categories", appConfig.language),
                        systemImage: "square.grid.2x2",
                        description: Text(L10n.tr("categories.tap_to_create", appConfig.language))
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
                    .onMove(perform: moveCategories)
                }
            }
        }
        .navigationTitle(L10n.tr("categories.title", appConfig.language))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: AppTheme.spacing12) {
                    EditButton()
                    Button {
                        showingAddCategory = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
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
        .alert(L10n.tr("categories.delete_title", appConfig.language), isPresented: .init(
            get: { deletingCategory != nil },
            set: { if !$0 { deletingCategory = nil } }
        )) {
            Button(L10n.tr("common.cancel", appConfig.language), role: .cancel) { deletingCategory = nil }
            Button(L10n.tr("common.delete", appConfig.language), role: .destructive) {
                if let category = deletingCategory {
                    deleteCategory(category)
                }
            }
        } message: {
            if let category = deletingCategory {
                Text(L10n.tr("categories.delete_message", appConfig.language, category.name))
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
                    Text(L10n.tr("categories.required", appConfig.language))
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

    // MARK: - Reorder

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var ordered = filteredCategories
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, category) in ordered.enumerated() {
            category.sortOrder = index
        }
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
