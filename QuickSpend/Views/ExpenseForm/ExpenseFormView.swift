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
                    Picker("Type", selection: $selectedType) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, AppTheme.spacing4)
                }

                // Note
                Section("Description") {
                    TextField("What did you spend on?", text: $noteText)
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

                // Date
                Section("Date") {
                    DatePicker(
                        "Date",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                }
            }
            .navigationTitle(isEditMode ? "Edit Transaction" : "Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
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
