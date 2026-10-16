import Foundation
import Testing
@testable import QuickSpend

@Suite("QuickLaunch Tests")
@MainActor
struct QuickLaunchTests {

    @Test("The voice action round-trips through its URL")
    func testVoiceURLRoundTrip() {
        let url = QuickLaunchAction.voiceExpense.url

        #expect(url.absoluteString == "quickspend://voice")
        #expect(QuickLaunchAction(url: url) == .voiceExpense)
    }

    @Test("URL parsing ignores case in scheme and host")
    func testURLParsingIsCaseInsensitive() {
        #expect(QuickLaunchAction(url: URL(string: "QuickSpend://VOICE")!) == .voiceExpense)
    }

    @Test("Unknown schemes and hosts are rejected")
    func testUnknownURLsRejected() {
        #expect(QuickLaunchAction(url: URL(string: "https://voice")!) == nil)
        #expect(QuickLaunchAction(url: URL(string: "quickspend://unknown")!) == nil)
        #expect(QuickLaunchAction(url: URL(string: "quickspend:")!) == nil)
    }

    @Test("A handled URL becomes the pending action until consumed once")
    func testHandleAndConsume() {
        let center = QuickLaunchCenter()

        #expect(center.handle(URL(string: "quickspend://voice")!) == true)
        #expect(center.pending == .voiceExpense)
        #expect(center.consume(.voiceExpense) == true)
        #expect(center.pending == nil)
        #expect(center.consume(.voiceExpense) == false)
    }

    @Test("An unrelated URL leaves nothing pending")
    func testHandleIgnoresUnrelatedURL() {
        let center = QuickLaunchCenter()

        #expect(center.handle(URL(string: "https://example.com")!) == false)
        #expect(center.pending == nil)
    }
}
