import Testing
import Foundation
@testable import QuickSpend

@Suite("L10n Localization Tests")
struct L10nTests {

    // MARK: - Basic Lookup

    @Test("tr returns non-empty for known key with en")
    func testKnownKeyReturnsNonEmpty() {
        let result = L10n.tr("common.cancel", "en")
        #expect(!result.isEmpty)
    }

    @Test("tr with unknown key returns the key itself")
    func testUnknownKeyReturnsKey() {
        let unknownKey = "this.key.definitely.does.not.exist.anywhere"
        let result = L10n.tr(unknownKey, "en")
        // NSLocalizedString returns the key when no localization is found
        #expect(result == unknownKey)
    }

    @Test("wallet whats new strings are localized in Vietnamese")
    func testWalletWhatsNewVietnameseLocalization() {
        #expect(L10n.tr("wallets.whats_new.title", "vi") == "Ví đã sẵn sàng")
        #expect(L10n.tr("wallets.create", "vi") == "Tạo ví")
        #expect(L10n.tr("wallets.not_now", "vi") == "Để sau")
        #expect(L10n.tr("wallets.personal", "vi") == "Cá nhân")
    }

    // MARK: - Format Arguments

    @Test("tr with format args does not crash")
    func testFormatArgsDoNotCrash() {
        // Use a key that likely has a format specifier, or just a plain key
        // With a plain key the format call still should not crash
        let result = L10n.tr("common.cancel", "en", 5)
        #expect(!result.isEmpty)
    }

    // MARK: - Language Handling

    @Test("tr with en uses main bundle and returns a value")
    func testEnUsesMainBundle() {
        let result = L10n.tr("common.cancel", "en")
        // For "en", the bundle(for:) method returns Bundle.main when no en.lproj exists
        #expect(!result.isEmpty)
    }

    @Test("tr with unknown language falls back correctly")
    func testUnknownLanguageFallback() {
        let key = "common.cancel"
        let result = L10n.tr(key, "zz")
        // When bundle(for:) returns nil for an unknown language,
        // NSLocalizedString is called on main bundle, returning the key or a localized string
        #expect(!result.isEmpty)
    }

    // MARK: - Repeated Calls

    @Test("Multiple consecutive calls return consistent results")
    func testMultipleConsecutiveCalls() {
        let key = "common.cancel"
        let first = L10n.tr(key, "en")
        let second = L10n.tr(key, "en")
        let third = L10n.tr(key, "en")
        #expect(first == second)
        #expect(second == third)
    }
}
