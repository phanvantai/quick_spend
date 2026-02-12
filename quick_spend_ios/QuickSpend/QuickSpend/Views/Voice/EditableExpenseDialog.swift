import SwiftUI

/// Dialog for reviewing and editing AI-parsed expenses before saving
struct EditableExpenseDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig

    let parsedExpenses: [ParsedExpense]
    let categories: [QuickCategory]
    let onSave: ([Expense]) -> Void

    @State private var editableExpenses: [EditableExpenseData]

    init(
        parsedExpenses: [ParsedExpense],
        categories: [QuickCategory],
        onSave: @escaping ([Expense]) -> Void
    ) {
        self.parsedExpenses = parsedExpenses
        self.categories = categories
        self.onSave = onSave
        _editableExpenses = State(initialValue: parsedExpenses.map { EditableExpenseData(from: $0) })
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(editableExpenses.indices, id: \.self) { index in
                    Section(editableExpenses.count > 1 ? "Expense \(index + 1)" : "Parsed Expense") {
                        expenseForm(at: index)
                    }
                }
            }
            .navigationTitle(editableExpenses.count > 1
                ? "\(editableExpenses.count) Expenses Parsed"
                : "Confirm Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                }
            }
        }
    }

    // MARK: - Expense Form

    @ViewBuilder
    private func expenseForm(at index: Int) -> some View {
        let data = editableExpenses[index]
        let filteredCategories = categories.filter { $0.type == data.type }

        // Type
        Picker("Type", selection: $editableExpenses[index].type) {
            Text("Expense").tag(TransactionType.expense)
            Text("Income").tag(TransactionType.income)
        }
        .pickerStyle(.segmented)
        .onChange(of: editableExpenses[index].type) {
            // Reset category when type changes
            let filtered = categories.filter { $0.type == editableExpenses[index].type }
            if !filtered.contains(where: { $0.id == editableExpenses[index].categoryId }) {
                editableExpenses[index].categoryId = filtered.first?.id ?? "other"
            }
        }

        // Description
        TextField("Description", text: $editableExpenses[index].descriptionText)
            .textInputAutocapitalization(.sentences)

        // Amount
        HStack {
            Text(appConfig.config.currencySymbol)
                .font(.body.bold())
                .foregroundStyle(.secondary)
            TextField("Amount", text: $editableExpenses[index].amountText)
                .keyboardType(.decimalPad)
                .font(.body.monospacedDigit())
        }

        // Category
        Picker("Category", selection: $editableExpenses[index].categoryId) {
            ForEach(filteredCategories, id: \.id) { category in
                HStack {
                    Image(systemName: category.iconName)
                    Text(category.name)
                }
                .tag(category.id)
            }
        }

        // Date
        DatePicker(
            "Date",
            selection: $editableExpenses[index].date,
            in: ...Date(),
            displayedComponents: [.date]
        )

        // Low confidence warning
        if data.confidence < AppConstants.confidenceWarningThreshold {
            HStack(spacing: AppTheme.spacing8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.warning)
                    .font(.caption)
                Text("Low confidence - please verify")
                    .font(.caption)
                    .foregroundStyle(AppTheme.warning)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Save

    private func save() {
        let expenses = editableExpenses.compactMap { data -> Expense? in
            let cleanedAmount = data.amountText
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: " ", with: "")
            guard let amount = Double(cleanedAmount), amount > 0 else { return nil }
            guard !data.descriptionText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

            return Expense(
                amount: amount,
                descriptionText: data.descriptionText.trimmingCharacters(in: .whitespaces),
                categoryId: data.categoryId,
                language: appConfig.language,
                date: data.date,
                userId: AppConstants.defaultUserId,
                rawInput: data.rawInput,
                confidence: data.confidence,
                type: data.type
            )
        }

        guard !expenses.isEmpty else { return }
        onSave(expenses)
        dismiss()
    }
}

// MARK: - Editable Data

struct EditableExpenseData {
    var descriptionText: String
    var amountText: String
    var categoryId: String
    var type: TransactionType
    var date: Date
    var confidence: Double
    var rawInput: String

    init(from parsed: ParsedExpense) {
        self.descriptionText = parsed.descriptionText
        self.amountText = String(format: parsed.amount == floor(parsed.amount) ? "%.0f" : "%.2f", parsed.amount)
        self.categoryId = parsed.categoryId
        self.type = parsed.type
        self.date = parsed.date
        self.confidence = parsed.confidence
        self.rawInput = parsed.descriptionText
    }
}
