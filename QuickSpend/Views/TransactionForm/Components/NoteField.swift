import SwiftUI

/// Optional note text field with inline error.
struct NoteField: View {
    @Binding var noteText: String
    let error: String?
    let language: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing8) {
            Text(L10n.tr("expense_form.note", language))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            TextField(
                L10n.tr("expense_form.enter_note", language),
                text: $noteText
            )
            .textInputAutocapitalization(.sentences)
            .font(.body)
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
