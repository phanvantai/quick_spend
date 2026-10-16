import SwiftUI

/// Expense / Income (/ Transfer) segmented toggle used at the top of the form.
struct TypeToggle: View {
    @Binding var selection: TransactionFormKind
    let kinds: [TransactionFormKind]
    let language: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(kinds, id: \.self) { kind in
                button(kind)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusXLarge)
                .fill(Color(.systemGray6))
        )
    }

    private func label(for kind: TransactionFormKind) -> String {
        switch kind {
        case .expense: return L10n.tr("common.expense", language)
        case .income: return L10n.tr("common.income", language)
        case .transfer: return L10n.tr("transfer.title", language)
        }
    }

    private func button(_ kind: TransactionFormKind) -> some View {
        Button {
            withAnimation(.easeQuick) {
                selection = kind
            }
        } label: {
            Text(label(for: kind))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.spacing12)
                .background {
                    if selection == kind {
                        Capsule()
                            .fill(FormFieldStyle.accent(colorScheme))
                    }
                }
                .foregroundStyle(selection == kind ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}
