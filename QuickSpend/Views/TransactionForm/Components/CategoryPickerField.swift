import SwiftUI

/// Category select button + grouped picker sheet.
struct CategoryPickerField: View {
    @Binding var selectedCategoryId: String?
    let categories: [Category]
    let selectedType: TransactionType
    let error: String?
    let language: String

    @State private var showPicker = false
    @Environment(\.colorScheme) private var colorScheme

    private var filteredCategories: [Category] {
        categories.filter { $0.type == selectedType && !$0.isHidden }
    }

    private var selectedCategory: Category? {
        guard let id = selectedCategoryId else { return nil }
        return categories.first { $0.id == id }
    }

    private var groupedCategories: [(group: CategoryGroup, categories: [Category])] {
        let grouped = Dictionary(grouping: filteredCategories) { $0.group ?? .other }
        let groupOrder: [CategoryGroup] = selectedType == .expense
            ? [.dailyLiving, .personal, .social, .financial, .other]
            : [.earned, .passive, .received, .other]
        return groupOrder.compactMap { group in
            guard let cats = grouped[group], !cats.isEmpty else { return nil }
            return (group: group, categories: cats.sorted { $0.sortOrder < $1.sortOrder })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(selectedType == .expense
                 ? L10n.tr("expense_form.expense_category", language)
                 : L10n.tr("expense_form.income_category", language))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Button {
                showPicker = true
            } label: {
                HStack {
                    if let category = selectedCategory {
                        HStack(spacing: AppTheme.spacing8) {
                            Image(systemName: category.iconName)
                                .foregroundStyle(category.color)
                            Text(category.name)
                                .foregroundStyle(.primary)
                        }
                    } else {
                        Text(L10n.tr("expense_form.select_category", language))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.body)
                .padding(.horizontal, AppTheme.spacing16)
                .padding(.vertical, AppTheme.spacing16)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .fill(FormFieldStyle.background(colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .stroke(error != nil ? Color.red : FormFieldStyle.border(colorScheme), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .sheet(isPresented: $showPicker) {
            pickerSheet
        }
    }

    private var pickerSheet: some View {
        NavigationStack {
            List {
                ForEach(groupedCategories, id: \.group) { section in
                    Section(groupName(for: section.group)) {
                        ForEach(section.categories, id: \.id) { category in
                            Button {
                                selectedCategoryId = category.id
                                showPicker = false
                            } label: {
                                HStack(spacing: AppTheme.spacing12) {
                                    Image(systemName: category.iconName)
                                        .font(.title3)
                                        .foregroundStyle(category.color)
                                        .frame(width: 32, alignment: .center)

                                    Text(category.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if category.id == selectedCategoryId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(FormFieldStyle.accent(colorScheme))
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(selectedType == .expense
                ? L10n.tr("expense_form.expense_category", language)
                : L10n.tr("expense_form.income_category", language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.done", language)) {
                        showPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

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
        return L10n.tr(key, language)
    }
}
