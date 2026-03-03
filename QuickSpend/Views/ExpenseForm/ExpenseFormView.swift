import SwiftUI
import SwiftData

/// Full-screen form for adding or editing a transaction
struct ExpenseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig

    let categories: [Category]
    let existingExpense: Transaction?
    let onSave: (Transaction) -> Void

    @State private var noteText: String
    @State private var amountText: String
    @State private var selectedCategoryId: String
    @State private var selectedDate: Date
    @State private var selectedType: TransactionType

    @State private var showAmountError = false

    private var isEditMode: Bool { existingExpense != nil }

    private var filteredCategories: [Category] {
        categories.filter { $0.type == selectedType }
    }

    init(
        categories: [Category],
        expense: Transaction? = nil,
        onSave: @escaping (Transaction) -> Void
    ) {
        self.categories = categories
        self.existingExpense = expense
        self.onSave = onSave

        _noteText = State(initialValue: expense?.note ?? "")
        _amountText = State(initialValue: expense.map { String(format: "%.2f", $0.amount) } ?? "")
        _selectedCategoryId = State(initialValue: expense?.categoryId ?? "other_expense")
        _selectedDate = State(initialValue: expense?.date ?? {
            let now = Date.now
            return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        }())
        _selectedType = State(initialValue: expense?.type ?? .expense)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Transaction type
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

                // Note
                Section(L10n.tr("common.description", appConfig.language)) {
                    TextField(L10n.tr("expense_form.what_spent", appConfig.language), text: $noteText)
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

                // Date
                Section(L10n.tr("common.date", appConfig.language)) {
                    DatePicker(
                        L10n.tr("common.date", appConfig.language),
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                }
            }
            .navigationTitle(isEditMode
                ? L10n.tr("expense_form.edit_title", appConfig.language)
                : L10n.tr("expense_form.add_title", appConfig.language))
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
                // Reset category when type changes if current doesn't match
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
        // Parse amount
        let cleanedAmount = amountText
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard let amount = Double(cleanedAmount), amount > 0 else {
            showAmountError = true
            return
        }
        showAmountError = false

        let transaction = Transaction(
            id: existingExpense?.id ?? UUID().uuidString,
            amount: amount,
            note: noteText.trimmingCharacters(in: .whitespaces),
            categoryId: selectedCategoryId,
            type: selectedType,
            date: selectedDate,
            rawInput: existingExpense?.rawInput,
            confidence: existingExpense?.confidence
        )

        onSave(transaction)
        dismiss()
    }
}

#Preview {
    ExpenseFormView(
        categories: CategoryService.defaultCategories(language: "en")
    ) { transaction in
        print("Saved: \(transaction.note) - \(transaction.amount)")
    }
    .environment(AppConfigViewModel())
}
