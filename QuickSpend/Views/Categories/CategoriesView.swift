import SwiftUI
import SwiftData

/// Category management screen with grid layout and expandable groups
struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppConfigViewModel.self) private var appConfig
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]

    @State private var showIncome = false
    @State private var showingAddCategory = false
    @State private var editingCategory: Category?
    @State private var deletingCategory: Category?
    @State private var searchText = ""
    @State private var collapsedGroups: Set<CategoryGroup> = []

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: AppTheme.spacing12), count: 3)

    private var selectedType: TransactionType {
        showIncome ? .income : .expense
    }

    private var filteredCategories: [Category] {
        let typeFiltered = allCategories.filter { !$0.isHidden && $0.type == selectedType }
        if searchText.isEmpty { return typeFiltered }
        return typeFiltered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
        ScrollView {
            VStack(spacing: AppTheme.spacing16) {
                // Type picker
                typePicker

                // Search bar
                searchBar

                // Category groups
                if filteredCategories.isEmpty {
                    emptyState
                } else {
                    ForEach(groupedCategories, id: \.group) { section in
                        categoryGroupCard(section.group, categories: section.categories)
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacing16)
            .padding(.bottom, AppTheme.spacing32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L10n.tr("categories.title", appConfig.language))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddCategory = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .tint(AppTheme.adaptiveAccent(colorScheme))
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
    }

    // MARK: - Type Picker

    private var typePicker: some View {
        Picker(L10n.tr("common.type", appConfig.language), selection: $showIncome) {
            Text(L10n.tr("common.expense", appConfig.language)).tag(false)
            Text(L10n.tr("common.income", appConfig.language)).tag(true)
        }
        .pickerStyle(.segmented)
        .padding(.top, AppTheme.spacing4)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: AppTheme.spacing8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L10n.tr("common.search", appConfig.language), text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(AppTheme.spacing12)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            L10n.tr("categories.no_categories", appConfig.language),
            systemImage: "square.grid.2x2",
            description: Text(L10n.tr("categories.tap_to_create", appConfig.language))
        )
        .padding(.top, AppTheme.spacing48)
    }

    // MARK: - Category Group Card

    private func categoryGroupCard(_ group: CategoryGroup, categories: [Category]) -> some View {
        let isCollapsed = collapsedGroups.contains(group)

        return VStack(spacing: 0) {
            // Group header
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if isCollapsed {
                        collapsedGroups.remove(group)
                    } else {
                        collapsedGroups.insert(group)
                    }
                }
            } label: {
                HStack(spacing: AppTheme.spacing8) {
                    Image(systemName: group.iconName)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.adaptiveAccent(colorScheme))

                    Text(groupName(for: group))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isCollapsed ? 180 : 0))
                }
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.vertical, AppTheme.spacing12)
            }
            .buttonStyle(.plain)

            // Grid content
            if !isCollapsed {
                LazyVGrid(columns: gridColumns, spacing: AppTheme.spacing16) {
                    ForEach(categories, id: \.id) { category in
                        categoryGridItem(category)
                    }
                }
                .padding(.horizontal, AppTheme.spacing12)
                .padding(.bottom, AppTheme.spacing16)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }

    // MARK: - Category Grid Item

    private func categoryGridItem(_ category: Category) -> some View {
        let isFallback = category.id == "other_expense" || category.id == "other_income"

        return Button {
            editingCategory = category
        } label: {
            VStack(spacing: AppTheme.spacing8) {
                CategoryIconBadge(
                    iconName: category.iconName,
                    color: category.color,
                    size: 48,
                    shape: .circle
                )

                Text(category.name)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 32)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingCategory = category
            } label: {
                Label(L10n.tr("common.edit", appConfig.language), systemImage: "pencil")
            }

            if !isFallback {
                Button(role: .destructive) {
                    deletingCategory = category
                } label: {
                    Label(L10n.tr("common.delete", appConfig.language), systemImage: "trash")
                }
            }
        }
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

    // MARK: - Actions

    private func deleteCategory(_ category: Category) {
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
