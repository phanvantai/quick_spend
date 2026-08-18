import SwiftUI

struct WalletWhatsNewModal: View {
    let onCreateWallet: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ModalTemplate(
            title: "Wallets are here",
            subtitle: "Your existing data is safely in Personal. Create another wallet when you want to separate side income, project costs, or travel money.",
            primary: ModalCTA(label: "Create Wallet", icon: "plus.circle.fill", action: onCreateWallet),
            secondary: ModalCTA(label: "Not Now", action: onDismiss)
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
