import SwiftUI

/// App bar with month navigation (reuses MonthNavigator) and currency badge
struct HomeAppBar: View {
    @Binding var selectedMonth: Date
    @Binding var selectedWalletScope: WalletScope
    let language: String
    let currency: String
    let wallets: [Wallet]

    /// Currency badge (trailing side of nav bar)
    private var currencyBadge: some View {
        Text(currency)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, AppTheme.spacing12)
            .padding(.vertical, AppTheme.spacing4)
            .background {
                Capsule()
                    .fill(Color(.tertiarySystemFill))
            }
    }

    private var selectedWallet: Wallet? {
        guard case .wallet(let walletId) = selectedWalletScope else { return nil }
        return wallets.first { $0.id == walletId }
    }

    private var selectedWalletTitle: String {
        switch selectedWalletScope {
        case .all:
            return L10n.tr("wallets.all", language)
        case .wallet:
            return selectedWallet?.displayName(language: language) ?? L10n.tr("wallets.wallet", language)
        }
    }

    private var selectedWalletIcon: String {
        switch selectedWalletScope {
        case .all:
            return "square.grid.2x2.fill"
        case .wallet:
            return selectedWallet?.iconName ?? "wallet.bifold.fill"
        }
    }

    private var selectedWalletColor: Color {
        switch selectedWalletScope {
        case .all:
            return AppTheme.primaryDark
        case .wallet:
            return selectedWallet?.color ?? AppTheme.primaryDark
        }
    }

    @ViewBuilder
    private var walletMenu: some View {
        if wallets.count > 1 {
            Menu {
                Button {
                    selectedWalletScope = .all
                } label: {
                    Label(
                        L10n.tr("wallets.all", language),
                        systemImage: selectedWalletScope == .all ? "checkmark.circle.fill" : "square.grid.2x2.fill"
                    )
                }

                ForEach(wallets, id: \.id) { wallet in
                    Button {
                        selectedWalletScope = .wallet(wallet.id)
                    } label: {
                        Label(
                            wallet.displayName(language: language),
                            systemImage: selectedWalletScope == .wallet(wallet.id) ? "checkmark.circle.fill" : wallet.iconName
                        )
                    }
                }
            } label: {
                HStack(spacing: AppTheme.spacing8) {
                    Image(systemName: selectedWalletIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedWalletColor)
                        .frame(width: 16, height: 16)

                    Text(selectedWalletTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, AppTheme.spacing12)
                .padding(.vertical, AppTheme.spacing4)
                .background {
                    Capsule()
                        .fill(selectedWalletColor.opacity(0.12))
                }
            }
            .menuOrder(.fixed)
        }
    }

    var body: some View {
        HStack(spacing: AppTheme.spacing12) {
            MonthNavigator(selectedMonth: $selectedMonth, language: language)
            Spacer()
            walletMenu
            currencyBadge
        }
    }
}

#Preview {
    @Previewable @State var month = Date()
    @Previewable @State var walletScope = WalletScope.wallet(Wallet.personalID)
    HomeAppBar(
        selectedMonth: $month,
        selectedWalletScope: $walletScope,
        language: "vi",
        currency: "VND",
        wallets: [
            Wallet.personal(),
            Wallet(name: "Làm thêm", iconName: "briefcase.fill", colorHex: "5A9BD5", sortOrder: 1),
        ]
    )
        .padding()
}
