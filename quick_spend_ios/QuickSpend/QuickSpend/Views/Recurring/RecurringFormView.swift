import SwiftUI

/// Form for adding or editing a recurring expense template
struct RecurringFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig

    let categories: [QuickCategory]
    let existingTemplate: RecurringTemplate?
    let onSave: (RecurringTemplate) -> Void

    @State private var descriptionText: String
    @State private var amountText: String
    @State private var selectedCategoryId: String
    @State private var selectedType: TransactionType
    @State private var selectedPattern: RecurrencePattern
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date

    @State private var showAmountError = false

    private var isEditMode: Bool { existingTemplate != nil }

    private var filteredCategories: [QuickCategory] {
        categories.filter { $0.type == selectedType }
    }

    init(
        categories: [QuickCategory],
        existingTemplate: RecurringTemplate? = nil,
        onSave: @escaping (RecurringTemplate) -> Void
    ) {
        self.categories = categories
        self.existingTemplate = existingTemplate
        self.onSave = onSave

        _descriptionText = State(initialValue: existingTemplate?.descriptionText ?? "")
        _amountText = State(initialValue: existingTemplate.map { String(format: "%.2f", $0.amount) } ?? "")
        _selectedCategoryId = State(initialValue: existingTemplate?.categoryId ?? "other")
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
                    Picker("Type", selection: $selectedType) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, AppTheme.spacing4)
                }

                // Description
                Section("Description") {
                    TextField("e.g. Monthly rent, Netflix", text: $descriptionText)
                        .textInputAutocapitalization(.sentences)
                }

                // Amount
                Section("Amount") {
                    HStack {
                        Text(appConfig.config.currencySymbol)
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title3.monospacedDigit())
                    }
                    if showAmountError {
                        Text("Please enter a valid amount")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Category
                Section("Category") {
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
                Section("Recurrence") {
                    Picker("Pattern", selection: $selectedPattern) {
                        Text("Monthly").tag(RecurrencePattern.monthly)
                        Text("Yearly").tag(RecurrencePattern.yearly)
                    }
                    .pickerStyle(.segmented)
                }

                // Dates
                Section("Schedule") {
                    DatePicker(
                        "Start Date",
                        selection: $startDate,
                        displayedComponents: [.date]
                    )

                    Toggle("Has End Date", isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker(
                            "End Date",
                            selection: $endDate,
                            in: startDate...,
                            displayedComponents: [.date]
                        )
                    }
                }
            }
            .navigationTitle(isEditMode ? "Edit Recurring" : "Add Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                        .disabled(descriptionText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: selectedType) {
                if !filteredCategories.contains(where: { $0.id == selectedCategoryId }) {
                    selectedCategoryId = filteredCategories.first?.id ?? "other"
                }
            }
        }
    }

    // MARK: - Category Chip

    private func categoryChip(_ category: QuickCategory) -> some View {
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
        let cleanedAmount = amountText
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard let amount = Double(cleanedAmount), amount > 0 else {
            showAmountError = true
            return
        }
        showAmountError = false

        let template = RecurringTemplate(
            id: existingTemplate?.id ?? UUID().uuidString,
            amount: amount,
            descriptionText: descriptionText.trimmingCharacters(in: .whitespaces),
            categoryId: selectedCategoryId,
            language: appConfig.language,
            userId: AppConstants.defaultUserId,
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
        categories: QuickCategory.defaultSystemCategories(language: "en")
    ) { template in
        print("Saved: \(template.descriptionText)")
    }
    .environment(AppConfigViewModel())
}
