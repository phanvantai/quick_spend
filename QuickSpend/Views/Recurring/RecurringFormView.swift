import SwiftUI

/// Form for adding or editing a recurring expense template
struct RecurringFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig

    let categories: [Category]
    let existingTemplate: RecurringTemplate?
    let onSave: (RecurringTemplate) -> Void

    @State private var noteText: String
    @State private var amountText: String
    @State private var selectedCategoryId: String
    @State private var selectedType: TransactionType
    @State private var selectedPattern: RecurrencePattern
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date

    @State private var showAmountError = false

    private var isEditMode: Bool { existingTemplate != nil }

    private var filteredCategories: [Category] {
        categories.filter { $0.type == selectedType }
    }

    init(
        categories: [Category],
        existingTemplate: RecurringTemplate? = nil,
        onSave: @escaping (RecurringTemplate) -> Void
    ) {
        self.categories = categories
        self.existingTemplate = existingTemplate
        self.onSave = onSave

        _noteText = State(initialValue: existingTemplate?.note ?? "")
        _amountText = State(initialValue: existingTemplate.map { String(format: "%.2f", $0.amount) } ?? "")
        _selectedCategoryId = State(initialValue: existingTemplate?.categoryId ?? "other_expense")
        _selectedType = State(initialValue: existingTemplate?.type ?? .expense)
        _selectedPattern = State(initialValue: existingTemplate?.pattern ?? .monthly)
        _startDate = State(initialValue: existingTemplate?.startDate ?? .now)
        _hasEndDate = State(initialValue: existingTemplate?.endDate != nil)
        _endDate = State(initialValue: existingTemplate?.endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: .now)!)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Transaction type
                Section {
                    TransactionTypePicker(selection: $selectedType, language: appConfig.language)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, AppTheme.spacing4)
                }

                // Description
                Section(L10n.tr("common.description", appConfig.language)) {
                    TextField(L10n.tr("recurring_form.placeholder", appConfig.language), text: $noteText)
                        .textInputAutocapitalization(.sentences)
                }

                // Amount
                Section(L10n.tr("common.amount", appConfig.language)) {
                    HStack {
                        Text(appConfig.config.currencySymbol)
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title3.monospacedDigit())
                            .onChange(of: amountText) {
                                let formatted = appConfig.config.formatAmountInput(amountText)
                                if formatted != amountText { amountText = formatted }
                            }
                    }
                    if showAmountError {
                        Text(L10n.tr("expense_form.invalid_amount", appConfig.language))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Category
                Section(L10n.tr("common.category", appConfig.language)) {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 90), spacing: AppTheme.spacing8)
                    ], spacing: AppTheme.spacing8) {
                        ForEach(filteredCategories, id: \.id) { category in
                            categoryChip(category)
                        }
                    }
                    .padding(.vertical, AppTheme.spacing4)
                }

                // Recurrence pattern
                Section(L10n.tr("recurring_form.recurrence", appConfig.language)) {
                    Picker(L10n.tr("recurring_form.pattern", appConfig.language), selection: $selectedPattern) {
                        Text(L10n.tr("recurring_form.pattern_daily", appConfig.language)).tag(RecurrencePattern.daily)
                        Text(L10n.tr("recurring_form.pattern_weekly", appConfig.language)).tag(RecurrencePattern.weekly)
                        Text(L10n.tr("recurring_form.pattern_monthly", appConfig.language)).tag(RecurrencePattern.monthly)
                        Text(L10n.tr("recurring_form.pattern_yearly", appConfig.language)).tag(RecurrencePattern.yearly)
                    }
                    .pickerStyle(.segmented)
                }

                // Dates
                Section(L10n.tr("recurring_form.schedule", appConfig.language)) {
                    DatePicker(
                        L10n.tr("recurring_form.start_date", appConfig.language),
                        selection: $startDate,
                        displayedComponents: [.date]
                    )

                    Toggle(L10n.tr("recurring_form.has_end_date", appConfig.language), isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker(
                            L10n.tr("recurring_form.end_date", appConfig.language),
                            selection: $endDate,
                            in: startDate...,
                            displayedComponents: [.date]
                        )
                    }
                }
            }
            .navigationTitle(isEditMode
                ? L10n.tr("recurring_form.edit_title", appConfig.language)
                : L10n.tr("recurring_form.add_title", appConfig.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel", appConfig.language)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save", appConfig.language)) { save() }
                        .bold()
                        .disabled(noteText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: selectedType) {
                if !filteredCategories.contains(where: { $0.id == selectedCategoryId }) {
                    selectedCategoryId = filteredCategories.first?.id ?? "other_expense"
                }
            }
        }
    }

    // MARK: - Category Chip

    private func categoryChip(_ category: Category) -> some View {
        let isSelected = category.id == selectedCategoryId
        return Button {
            selectedCategoryId = category.id
        } label: {
            HStack(spacing: 4) {
                Image(systemName: category.iconName)
                    .font(.caption)
                Text(category.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, AppTheme.spacing8)
            .padding(.vertical, AppTheme.spacing8)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                    .fill(isSelected ? category.color.opacity(0.2) : Color(.tertiarySystemGroupedBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                    .stroke(isSelected ? category.color : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? category.color : .primary)
    }

    // MARK: - Save

    private func save() {
        guard let amount = appConfig.config.parseAmount(amountText), amount > 0 else {
            showAmountError = true
            return
        }
        showAmountError = false

        let template = RecurringTemplate(
            id: existingTemplate?.id ?? UUID().uuidString,
            amount: amount,
            note: noteText.trimmingCharacters(in: .whitespaces),
            categoryId: selectedCategoryId,
            type: selectedType,
            pattern: selectedPattern,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            lastGeneratedDate: existingTemplate?.lastGeneratedDate,
            isActive: existingTemplate?.isActive ?? true
        )

        onSave(template)
        dismiss()
    }
}

#Preview {
    RecurringFormView(
        categories: CategoryService.defaultCategories(language: "en")
    ) { template in
        print("Saved: \(template.note)")
    }
    .environment(AppConfigViewModel())
}
