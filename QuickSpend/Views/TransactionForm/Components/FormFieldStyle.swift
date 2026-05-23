import SwiftUI

/// Shared chrome for TransactionForm field components.
enum FormFieldStyle {
    static func background(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(.secondarySystemGroupedBackground) : Color(.systemBackground)
    }

    static func border(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(.systemGray4) : Color(.systemGray5)
    }

    static func accent(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? AppTheme.primaryLight : AppTheme.primaryMint
    }
}
