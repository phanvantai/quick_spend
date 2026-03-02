import SwiftUI

/// Dialog for reviewing and editing AI-parsed transactions before saving
struct EditableExpenseDialog: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigViewModel.self) private var appConfig

    let parsedTransactions: [ParsedTransaction]
    let categories: [Category]
    let onSave: ([Transaction]) -> Void

    @State private var editableExpenses: [EditableExpenseData]

    private var isVi: Bool { appConfig.language == "vi" }

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
                    Button(isVi ? "Hủy" : "Discard") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isVi ? "Lưu" : "Save") { save() }
                        .bold()
                }
            }
        }
    }

    // MARK: - Titles

    private var navTitle: String {
        if editableExpenses.count > 1 {
            let count = editableExpenses.count
            return isVi ? "\(count) giao dịch" : "\(count) Transactions Parsed"
        }
        return isVi ? "Xác nhận giao dịch" : "Confirm Transaction"
    }

    private func sectionTitle(index: Int) -> String {
        guard editableExpenses.count > 1 else {
            return isVi ? "Giao dịch" : "Transaction"
        }
        return isVi ? "Giao dịch \(index + 1)" : "Transaction \(index + 1)"
    }

    // MARK: - Expense Form

    @ViewBuilder
    private func expenseForm(at index: Int) -> some View {
        let data = editableExpenses[index]
        let filteredCategories = categories.filter { $0.type == data.type }

        // Type
        Picker(isVi ? "Loại" : "Type", selection: $editableExpenses[index].type) {
            Text(isVi ? "Chi tiêu" : "Expense").tag(TransactionType.expense)
            Text(isVi ? "Thu nhập" : "Income").tag(TransactionType.income)
        }
        .pickerStyle(.segmented)
        .onChange(of: editableExpenses[index].type) {
            // Reset category when type changes
            let filtered = categories.filter { $0.type == editableExpenses[index].type }
            if !filtered.contains(where: { $0.id == editableExpenses[index].categoryId }) {
                editableExpenses[index].categoryId = filtered.first?.id ?? "other_expense"
            }
        }

        // Note
        TextField(isVi ? "Mô tả" : "Description", text: $editableExpenses[index].note)
            .textInputAutocapitalization(.sentences)

        // Amount
        HStack {
            Text(appConfig.config.currencySymbol)
                .font(.body.bold())
                .foregroundStyle(.secondary)
            TextField(isVi ? "Số tiền" : "Amount", text: $editableExpenses[index].amountText)
                .keyboardType(.decimalPad)
                .font(.body.monospacedDigit())
        }

        // Category
        Picker(isVi ? "Danh mục" : "Category", selection: $editableExpenses[index].categoryId) {
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
            isVi ? "Ngày" : "Date",
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
                Text(isVi ? "Độ chính xác thấp - vui lòng kiểm tra" : "Low confidence - please verify")
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
