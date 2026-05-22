import SwiftUI

/// Amount text field with currency symbol suffix and inline error.
struct AmountInputField: View {
    @Binding var amountText: String
    let currency: String
    let error: String?
    let language: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(L10n.tr("expense_form.transaction_amount", language))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            HStack {
                TextField(
                    L10n.tr("expense_form.enter_amount", language),
                    text: $amountText
                )
                .keyboardType(.decimalPad)
                .font(.body)

                Text(currency)
                    .font(.body.weight(.medium))
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

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}
