import SwiftUI

/// Reusable segmented picker for switching between expense and income types
struct TransactionTypePicker: View {
    @Binding var selection: TransactionType
    let language: String

    var body: some View {
        Picker(L10n.tr("common.type", language), selection: $selection) {
            Text(L10n.tr("common.expense", language)).tag(TransactionType.expense)
            Text(L10n.tr("common.income", language)).tag(TransactionType.income)
        }
        .pickerStyle(.segmented)
    }
}
