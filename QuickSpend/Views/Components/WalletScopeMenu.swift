import SwiftUI

struct WalletScopeMenu: View {
    @Binding var selectedScope: WalletScope
    let language: String
    let wallets: [Wallet]

    private var selectedWallet: Wallet? {
        guard case .wallet(let walletId) = effectiveScope else { return nil }
        return wallets.first { $0.id == walletId }
    }

    private var effectiveScope: WalletScope {
        guard wallets.count > 1 else {
            return .wallet(wallets.first?.id ?? Wallet.personalID)
        }

        switch selectedScope {
        case .all:
            return .all
        case .wallet(let walletId):
            return wallets.contains { $0.id == walletId }
                ? selectedScope
                : .wallet(wallets.first?.id ?? Wallet.personalID)
        }
    }

    private var title: String {
        switch effectiveScope {
        case .all:
            return L10n.tr("wallets.all", language)
        case .wallet:
            return selectedWallet?.displayName(language: language) ?? L10n.tr("wallets.wallet", language)
        }
    }

    private var iconName: String {
        switch effectiveScope {
        case .all:
            return "square.grid.2x2.fill"
        case .wallet:
            return selectedWallet?.iconName ?? "wallet.bifold.fill"
        }
    }

    private var tint: Color {
        switch effectiveScope {
        case .all:
            return AppTheme.primaryDark
        case .wallet:
            return selectedWallet?.color ?? AppTheme.primaryDark
        }
    }

    var body: some View {
        if wallets.count > 1 {
            Menu {
                Button {
                    selectedScope = .all
                } label: {
                    Label(
                        L10n.tr("wallets.all", language),
                        systemImage: effectiveScope == .all ? "checkmark.circle.fill" : "square.grid.2x2.fill"
                    )
                }

                ForEach(wallets, id: \.id) { wallet in
                    Button {
                        selectedScope = .wallet(wallet.id)
                    } label: {
                        Label(
                            wallet.displayName(language: language),
                            systemImage: effectiveScope == .wallet(wallet.id) ? "checkmark.circle.fill" : wallet.iconName
                        )
                    }
                }
            } label: {
                HStack(spacing: AppTheme.spacing8) {
                    Image(systemName: iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 16, height: 16)

                    Text(title)
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
                .frame(maxWidth: 180)
                .background {
                    Capsule()
                        .fill(tint.opacity(0.12))
                }
            }
            .menuOrder(.fixed)
        }
    }
}

#Preview {
    @Previewable @State var scope = WalletScope.wallet(Wallet.personalID)

    WalletScopeMenu(
        selectedScope: $scope,
        language: "vi",
        wallets: [
            Wallet.personal(),
            Wallet(name: "Làm thêm", iconName: "briefcase.fill", colorHex: "5A9BD5", sortOrder: 1),
        ]
    )
    .padding()
}
