import SwiftUI

/// Dialog for reviewing and editing AI-parsed transactions before saving
struct EditableExpenseDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig

    let parsedTransactions: [ParsedTransaction]
    let categories: [Category]
    let onSave: ([Transaction]) -> Void

    @State private var editableExpenses: [EditableExpenseData]

    init(
        parsedExpenses: [ParsedTransaction],
        categories: [Category],
        onSave: @escaping ([Transaction]) -> Void
    ) {
        self.parsedTransactions = parsedExpenses
        self.categories = categories
        self.onSave = onSave
        _editableExpenses = State(initialValue: parsedExpenses.map { EditableExpenseData(from: $0) })
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(editableExpenses.indices, id: \.self) { index in
                    Section(sectionTitle(index: index)) {
                        expenseForm(at: index)
                    }
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.discard", appConfig.language)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save", appConfig.language)) { save() }
                        .bold()
                }
            }
        }
    }

    // MARK: - Titles

    private var navTitle: String {
        if editableExpenses.count > 1 {
            let count = editableExpenses.count
            return L10n.tr("voice_review.transactions_parsed", appConfig.language, count)
        }
        return L10n.tr("voice_review.confirm_title", appConfig.language)
    }

    private func sectionTitle(index: Int) -> String {
        guard editableExpenses.count > 1 else {
            return L10n.tr("voice_review.transaction", appConfig.language)
        }
        return L10n.tr("voice_review.transaction_n", appConfig.language, index + 1)
    }

    // MARK: - Expense Form

    @ViewBuilder
    private func expenseForm(at index: Int) -> some View {
        let data = editableExpenses[index]
        let filteredCategories = categories.filter { $0.type == data.type }

        // Type
        TransactionTypePicker(selection: $editableExpenses[index].type, language: appConfig.language)
        .onChange(of: editableExpenses[index].type) {
            // Reset category when type changes
            let filtered = categories.filter { $0.type == editableExpenses[index].type }
            if !filtered.contains(where: { $0.id == editableExpenses[index].categoryId }) {
                editableExpenses[index].categoryId = filtered.first?.id ?? "other_expense"
            }
        }

        // Note
        TextField(L10n.tr("common.description", appConfig.language), text: $editableExpenses[index].note)
            .textInputAutocapitalization(.sentences)

        // Amount
        HStack {
            Text(appConfig.config.currencySymbol)
                .font(.body.bold())
                .foregroundStyle(.secondary)
            TextField(L10n.tr("common.amount", appConfig.language), text: $editableExpenses[index].amountText)
                .keyboardType(.decimalPad)
                .font(.body.monospacedDigit())
        }

        // Category
        Picker(L10n.tr("common.category", appConfig.language), selection: $editableExpenses[index].categoryId) {
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
            L10n.tr("common.date", appConfig.language),
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
                Text(L10n.tr("voice_review.low_confidence", appConfig.language))
                    .font(.caption)
                    .foregroundStyle(AppTheme.warning)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Save

    private func save() {
        let transactions = editableExpenses.compactMap { data -> Transaction? in
            let cleanedAmount = data.amountText
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: " ", with: "")
            guard let amount = Double(cleanedAmount), amount > 0 else { return nil }
            guard !data.note.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

            return Transaction(
                amount: amount,
                note: data.note.trimmingCharacters(in: .whitespaces),
                categoryId: data.categoryId,
                type: data.type,
                date: data.date,
                rawInput: data.rawInput,
                confidence: data.confidence
            )
        }

        guard !transactions.isEmpty else { return }
        onSave(transactions)
        dismiss()
    }
}

// MARK: - Editable Data

struct EditableExpenseData {
    var note: String
    var amountText: String
    var categoryId: String
    var type: TransactionType
    var date: Date
    var confidence: Double
    var rawInput: String

    init(from parsed: ParsedTransaction) {
        self.note = parsed.note
        self.amountText = String(format: parsed.amount == floor(parsed.amount) ? "%.0f" : "%.2f", parsed.amount)
        self.categoryId = parsed.categoryId
        self.type = parsed.type
        self.date = parsed.date
        self.confidence = parsed.confidence
        self.rawInput = parsed.note
    }
}
