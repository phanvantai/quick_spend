import SwiftUI

/// Expense / Income segmented toggle used at the top of the form.
struct TypeToggle: View {
    @Binding var selectedType: TransactionType
    let language: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            button(.expense, label: L10n.tr("common.expense", language))
            button(.income, label: L10n.tr("common.income", language))
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusXLarge)
                .fill(Color(.systemGray6))
        )
    }

    private func button(_ type: TransactionType, label: String) -> some View {
        Button {
            withAnimation(.easeQuick) {
                selectedType = type
            }
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.spacing12)
                .background {
                    if selectedType == type {
                        Capsule()
                            .fill(FormFieldStyle.accent(colorScheme))
                    }
                }
                .foregroundStyle(selectedType == type ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}
