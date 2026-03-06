import SwiftUI

/// Form for adding or editing a category with icon and color pickers
struct CategoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig

    let existingCategory: Category?
    let onSave: (Category) -> Void

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColorHex: String
    @State private var selectedType: TransactionType

    @State private var showNameError = false

    private var isEditMode: Bool { existingCategory != nil }

    init(
        existingCategory: Category? = nil,
        defaultType: TransactionType = .expense,
        onSave: @escaping (Category) -> Void
    ) {
        self.existingCategory = existingCategory
        self.onSave = onSave
        _name = State(initialValue: existingCategory?.name ?? "")
        _selectedIcon = State(initialValue: existingCategory?.iconName ?? Self.availableIcons[0])
        _selectedColorHex = State(initialValue: existingCategory?.colorHex ?? Self.availableColorHexes[0])
        _selectedType = State(initialValue: existingCategory?.type ?? defaultType)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Preview
                Section {
                    previewCard
                }

                // Type
                Section {
                    Picker(L10n.tr("common.type", appConfig.language), selection: $selectedType) {
                        Text(L10n.tr("common.expense", appConfig.language)).tag(TransactionType.expense)
                        Text(L10n.tr("common.income", appConfig.language)).tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, AppTheme.spacing4)
                }

                // Name
                Section(L10n.tr("category_form.details", appConfig.language)) {
                    TextField(L10n.tr("category_form.name_placeholder", appConfig.language), text: $name)
                        .textInputAutocapitalization(.words)
                    if showNameError {
                        Text(L10n.tr("category_form.name_required", appConfig.language))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Icon Picker
                Section(L10n.tr("category_form.icon", appConfig.language)) {
                    iconPicker
                }

                // Color Picker
                Section(L10n.tr("category_form.color", appConfig.language)) {
                    colorPicker
                }
            }
            .navigationTitle(isEditMode
                ? L10n.tr("category_form.edit_title", appConfig.language)
                : L10n.tr("category_form.add_title", appConfig.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel", appConfig.language)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save", appConfig.language)) { save() }
                        .bold()
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        HStack(spacing: AppTheme.spacing12) {
            CategoryIconBadge(
                iconName: selectedIcon,
                color: Color(hex: selectedColorHex),
                size: 48,
                iconFont: .title3
            )

            Text(name.isEmpty ? L10n.tr("category_form.preview_name", appConfig.language) : name)
                .font(.headline)
                .foregroundStyle(name.isEmpty ? .tertiary : .primary)
        }
    }

    // MARK: - Icon Picker

    private var iconPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: AppTheme.spacing8)], spacing: AppTheme.spacing8) {
            ForEach(Self.availableIcons, id: \.self) { iconName in
                let isSelected = iconName == selectedIcon
                Button {
                    selectedIcon = iconName
                } label: {
                    Image(systemName: iconName)
                        .font(.body)
                        .frame(width: 44, height: 44)
                        .background {
                            RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                                .fill(isSelected ? Color(hex: selectedColorHex).opacity(0.2) : Color(.tertiarySystemGroupedBackground))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                                .stroke(isSelected ? Color(hex: selectedColorHex) : .clear, lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSelected ? Color(hex: selectedColorHex) : .primary)
            }
        }
        .padding(.vertical, AppTheme.spacing4)
    }

    // MARK: - Color Picker

    private var colorPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: AppTheme.spacing12)], spacing: AppTheme.spacing12) {
            ForEach(Self.availableColorHexes, id: \.self) { hex in
                let isSelected = hex == selectedColorHex
                Button {
                    selectedColorHex = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 44, height: 44)
                        .overlay {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.body.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay {
                            Circle()
                                .stroke(isSelected ? Color.primary : .clear, lineWidth: 3)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, AppTheme.spacing4)
    }

    // MARK: - Save

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            showNameError = true
            return
        }
        showNameError = false

        let category = Category(
            id: existingCategory?.id ?? trimmedName.lowercased().replacingOccurrences(of: " ", with: "_"),
            name: trimmedName,
            iconName: selectedIcon,
            colorHex: selectedColorHex,
            type: selectedType
        )

        onSave(category)
        dismiss()
    }

    // MARK: - Available Icons (SF Symbols)

    static let availableIcons: [String] = [
        // Food & Dining
        "fork.knife", "cup.and.saucer.fill", "wineglass.fill", "takeoutbag.and.cup.and.straw.fill",
        "birthday.cake.fill",

        // Shopping
        "bag.fill", "cart.fill", "storefront.fill", "tshirt.fill",

        // Transport
        "car.fill", "bus.fill", "tram.fill", "airplane", "bicycle",
        "fuelpump.fill", "parkingsign.circle.fill",

        // Entertainment
        "film.fill", "music.note", "headphones", "gamecontroller.fill",
        "theatermasks.fill", "sportscourt.fill",

        // Health
        "cross.case.fill", "pill.fill", "heart.fill",
        "figure.run", "dumbbell.fill",

        // Education & Work
        "book.fill", "graduationcap.fill", "briefcase.fill",
        "desktopcomputer", "laptopcomputer",

        // Home & Living
        "house.fill", "bed.double.fill", "sofa.fill",
        "lightbulb.fill", "wrench.and.screwdriver.fill",

        // Bills & Finance
        "doc.text.fill", "creditcard.fill", "banknote.fill",
        "wallet.bifold.fill", "chart.line.uptrend.xyaxis",

        // Personal
        "figure.and.child.holdinghands", "pawprint.fill",
        "gift.fill", "camera.fill", "suitcase.fill",

        // Misc
        "ellipsis.circle.fill", "plus.circle.fill", "star.fill",
        "tag.fill", "questionmark.circle.fill",
        "arrow.uturn.backward.circle.fill",
    ]

    // MARK: - Available Colors

    static let availableColorHexes: [String] = [
        "FF3B30", // Red
        "FF6B9D", // Pink
        "AF52DE", // Purple
        "5856D6", // Indigo
        "5F5CF1", // Blue-violet
        "007AFF", // Blue
        "5AC8FA", // Light Blue
        "00D9C0", // Teal
        "34C759", // Green
        "4CAF50", // Medium Green
        "00C896", // Mint
        "FFCC00", // Yellow
        "FF9800", // Orange
        "FF8C42", // Dark Orange
        "FF5757", // Coral
        "8E8E93", // Gray
        "6C5CE7", // Lavender
        "2196F3", // Bright Blue
        "009688", // Dark Teal
    ]
}

#Preview {
    CategoryFormView { category in
        print("Saved: \(category.name)")
    }
    .environment(AppConfigViewModel())
}
