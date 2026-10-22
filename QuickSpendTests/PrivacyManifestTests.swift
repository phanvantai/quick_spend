import Testing
import Foundation
@testable import QuickSpend

/// The app's PrivacyInfo.xcprivacy must ship in the bundle and match the App Privacy answers.
@Suite("Privacy manifest")
struct PrivacyManifestTests {
    private let manifest: [String: Any]

    init() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        manifest = try #require(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
    }

    private var collectedTypes: [[String: Any]] {
        manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []
    }

    @Test("Declares no tracking")
    func noTracking() {
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [String])?.isEmpty == true)
        #expect(collectedTypes.allSatisfy { $0["NSPrivacyCollectedDataTypeTracking"] as? Bool == false })
    }

    @Test("Declares the UserDefaults reason")
    func userDefaultsReason() {
        let apis = manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
        let userDefaults = apis.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" }
        #expect((userDefaults?["NSPrivacyAccessedAPITypeReasons"] as? [String]) == ["CA92.1"])
    }

    @Test("Declares the data the app sends out, unlinked")
    func collectedDataTypes() {
        let types = Set(collectedTypes.compactMap { $0["NSPrivacyCollectedDataType"] as? String })
        #expect(types == [
            "NSPrivacyCollectedDataTypeOtherUserContent",
            "NSPrivacyCollectedDataTypeOtherFinancialInfo",
            "NSPrivacyCollectedDataTypeUserID",
        ])
        #expect(collectedTypes.allSatisfy { $0["NSPrivacyCollectedDataTypeLinked"] as? Bool == false })
    }
}
