import SwiftUI

/// Date picker row + bottom sheet.
struct DateRow: View {
    @Binding var selectedDate: Date
    let error: String?
    let language: String

    @State private var showDatePicker = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(L10n.tr("expense_form.transaction_date", language))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Button {
                showDatePicker = true
            } label: {
                HStack {
                    Text(formattedDate)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                }
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
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: selectedDate)
    }

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .tint(FormFieldStyle.accent(colorScheme))
            .labelsHidden()
            .padding()
            .navigationTitle(L10n.tr("expense_form.transaction_date", language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.done", language)) {
                        showDatePicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
