import Foundation

/// One-line summaries of parsed voice results, shared by the in-app toast and
/// the Siri dialogs so both describe the same thing the same way.
enum VoiceSummary {
    /// After saving: "Added 50,000 ₫ for coffee", "Moved 2,000,000 ₫ from Cash
    /// to Bank", or "Added 3 expenses".
    static func saved(_ items: [ParsedTransaction], wallets: [Wallet], config: AppConfig) -> String {
        line(items, wallets: wallets, config: config,
             one: "intent.auto_saved_one", transfer: "voice.transfer_saved", many: "intent.auto_saved_many")
    }

    /// Before saving (Siri confirmation card).
    static func confirmation(_ items: [ParsedTransaction], wallets: [Wallet], config: AppConfig) -> String {
        line(items, wallets: wallets, config: config,
             one: "intent.confirm_one", transfer: "intent.confirm_transfer", many: "intent.confirm_many")
    }

    static func walletName(_ id: String?, wallets: [Wallet], language: String) -> String {
        wallets.first { $0.id == id }?.displayName(language: language) ?? ""
    }

    private static func line(
        _ items: [ParsedTransaction],
        wallets: [Wallet],
        config: AppConfig,
        one: String,
        transfer: String,
        many: String
    ) -> String {
        let language = config.language
        guard items.count == 1, let item = items.first else {
            return L10n.tr(many, language, items.count)
        }
        let amount = config.formatCurrency(item.amount)
        if item.isTransfer {
            return L10n.tr(
                transfer,
                language,
                amount,
                walletName(item.walletId, wallets: wallets, language: language),
                walletName(item.transferToWalletId, wallets: wallets, language: language)
            )
        }
        return L10n.tr(one, language, amount, item.note)
    }
}
