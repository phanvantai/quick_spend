import SwiftUI

struct WalletWhatsNewModal: View {
    @Environment(AppConfigViewModel.self) private var appConfig

    let onCreateWallet: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ModalTemplate(
            title: L10n.tr("wallets.whats_new.title", appConfig.language),
            subtitle: L10n.tr("wallets.whats_new.subtitle", appConfig.language),
            primary: ModalCTA(label: L10n.tr("wallets.create", appConfig.language), icon: "plus.circle.fill", action: onCreateWallet),
            secondary: ModalCTA(label: L10n.tr("wallets.not_now", appConfig.language), action: onDismiss)
        ) {
            ModalGradientHero(
                icon: "wallet.pass.fill",
                gradient: LinearGradient(
                    colors: [AppTheme.incomeColor, AppTheme.primaryDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                glowColor: AppTheme.incomeColor,
                animatedSymbol: false
            )
        } content: {
            EmptyView()
        }
    }
}
