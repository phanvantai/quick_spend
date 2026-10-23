import Testing
@testable import QuickSpend

@Suite("ReviewPromptPolicy Tests")
struct ReviewPromptPolicyTests {

    @Test("Asks after 3 voice saves")
    func asksAfterThreeSaves() {
        #expect(ReviewPromptPolicy.voiceSavesBeforePrompt == 3)
        #expect(!ReviewPromptPolicy.shouldRequest(voiceSaveCount: 2, lastPromptVersion: nil, currentVersion: "9.9.9-test"))
        #expect(ReviewPromptPolicy.shouldRequest(voiceSaveCount: 3, lastPromptVersion: nil, currentVersion: "9.9.9-test"))
        #expect(ReviewPromptPolicy.shouldRequest(voiceSaveCount: 40, lastPromptVersion: nil, currentVersion: "9.9.9-test"))
    }

    @Test("Asks once per app version")
    func asksOncePerVersion() {
        #expect(!ReviewPromptPolicy.shouldRequest(voiceSaveCount: 5, lastPromptVersion: "9.9.9-test", currentVersion: "9.9.9-test"))
        #expect(ReviewPromptPolicy.shouldRequest(voiceSaveCount: 5, lastPromptVersion: "9.9.8-test", currentVersion: "9.9.9-test"))
    }
}
