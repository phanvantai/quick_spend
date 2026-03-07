import SwiftUI
import SwiftData

/// Category management screen
struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]

    @Environment(\.editMode) private var editMode

    @State private var showIncome = false
    @State private var showingAddCategory = false
    @State private var editingCategory: Category?
    @State private var deletingCategory: Category?

    private var selectedType: TransactionType {
        showIncome ? .income : .expense
    }

    private var filteredCategories: [Category] {
        allCategories.filter { !$0.isHidden && $0.type == selectedType }
    }

    private var groupOrder: [CategoryGroup] {
        selectedType == .expense
            ? [.dailyLiving, .personal, .social, .financial, .other]
            : [.earned, .passive, .received, .other]
    }

    private var groupedCategories: [(group: CategoryGroup, categories: [Category])] {
        let grouped = Dictionary(grouping: filteredCategories) { $0.group ?? .other }
        return groupOrder.compactMap { group in
            guard let cats = grouped[group], !cats.isEmpty else { return nil }
            return (group: group, categories: cats.sorted { $0.sortOrder < $1.sortOrder })
        }
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

            // Categories grouped by CategoryGroup
            if filteredCategories.isEmpty {
                Section {
                    ContentUnavailableView(
                        L10n.tr("categories.no_categories", appConfig.language),
                        systemImage: "square.grid.2x2",
                        description: Text(L10n.tr("categories.tap_to_create", appConfig.language))
                    )
                }
            } else {
                ForEach(groupedCategories, id: \.group) { section in
                    Section(groupName(for: section.group)) {
                        ForEach(section.categories, id: \.id) { category in
                            categoryRow(category)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deletingCategory = category
                                    } label: {
                                        Label(L10n.tr("common.delete", appConfig.language), systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        editingCategory = category
                                    } label: {
                                        Label(L10n.tr("common.edit", appConfig.language), systemImage: "pencil")
                                    }
                                    .tint(AppTheme.adaptiveAccent(colorScheme))
                                }
                        }
                        .onMove { source, destination in
                            moveCategories(in: section.group, from: source, to: destination)
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.tr("categories.title", appConfig.language))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: AppTheme.spacing12) {
                    Button {
                        withAnimation {
                            if editMode?.wrappedValue == .active {
                                editMode?.wrappedValue = .inactive
                            } else {
                                editMode?.wrappedValue = .active
                            }
                        }
                    } label: {
                        Text(editMode?.wrappedValue == .active
                             ? L10n.tr("common.done", appConfig.language)
                             : L10n.tr("common.edit", appConfig.language))
                    }
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
                category.iconName = updated.iconName
                category.colorHex = updated.colorHex
                category.type = updated.type
                category.group = updated.group
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
        .tint(AppTheme.adaptiveAccent(colorScheme))
    }

    // MARK: - Category Row

    private func categoryRow(_ category: Category) -> some View {
        let isFallback = category.id == "other_expense" || category.id == "other_income"

        return HStack(spacing: AppTheme.spacing12) {
            CategoryIconBadge(
                iconName: category.iconName,
                color: category.color,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.body)
                if isFallback {
                    Text(L10n.tr("categories.required", appConfig.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    // MARK: - Group Name

    private func groupName(for group: CategoryGroup) -> String {
        let key: String
        switch group {
        case .dailyLiving: key = "category_group.daily_living"
        case .personal: key = "category_group.personal"
        case .social: key = "category_group.social"
        case .financial: key = "category_group.financial"
        case .earned: key = "category_group.earned"
        case .passive: key = "category_group.passive"
        case .received: key = "category_group.received"
        case .other: key = "category_group.other"
        }
        return L10n.tr(key, appConfig.language)
    }

    // MARK: - Reorder

    private func moveCategories(in group: CategoryGroup, from source: IndexSet, to destination: Int) {
        guard var sectionCats = groupedCategories.first(where: { $0.group == group })?.categories else { return }
        sectionCats.move(fromOffsets: source, toOffset: destination)
        for (index, category) in sectionCats.enumerated() {
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
