import Testing
import Foundation
import SwiftUI
@testable import QuickSpend

@Suite("FeatureRequest Model Tests")
struct FeatureRequestTests {

    // MARK: - FeatureRequest

    @Test("FeatureRequest initializes with correct values")
    func testInitialization() {
        let now = Date.now
        let request = FeatureRequest(
            id: "req_1",
            userId: "user_1",
            title: "Dark mode",
            description: "Add dark mode support",
            category: .newFeature,
            status: .pending,
            createdAt: now,
            updatedAt: now,
            appVersion: "1.0.0",
            language: "en",
            adminResponse: nil
        )

        #expect(request.id == "req_1")
        #expect(request.userId == "user_1")
        #expect(request.title == "Dark mode")
        #expect(request.description == "Add dark mode support")
        #expect(request.category == .newFeature)
        #expect(request.status == .pending)
        #expect(request.appVersion == "1.0.0")
        #expect(request.language == "en")
        #expect(request.adminResponse == nil)
    }

    @Test("FeatureRequest with admin response")
    func testWithAdminResponse() {
        let request = FeatureRequest(
            id: "req_1",
            userId: "user_1",
            title: "Bug",
            description: "Fix crash",
            category: .bugReport,
            status: .completed,
            createdAt: .now,
            updatedAt: .now,
            appVersion: "1.0.0",
            language: "en",
            adminResponse: "Fixed in v1.1"
        )

        #expect(request.adminResponse == "Fixed in v1.1")
        #expect(request.status == .completed)
    }

    @Test("FeatureRequest is Codable")
    func testCodable() throws {
        let request = FeatureRequest(
            id: "req_1",
            userId: "user_1",
            title: "Test",
            description: "Test description",
            category: .improvement,
            status: .underReview,
            createdAt: Date(timeIntervalSince1970: 1000000),
            updatedAt: Date(timeIntervalSince1970: 1000000),
            appVersion: "1.0.0",
            language: "vi",
            adminResponse: nil
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(FeatureRequest.self, from: data)

        #expect(decoded.id == request.id)
        #expect(decoded.title == request.title)
        #expect(decoded.category == request.category)
        #expect(decoded.status == request.status)
        #expect(decoded.language == request.language)
    }

    // MARK: - RequestCategory

    @Test("RequestCategory has all 4 cases")
    func testRequestCategoryCases() {
        let cases = RequestCategory.allCases
        #expect(cases.count == 4)
        #expect(cases.contains(.newFeature))
        #expect(cases.contains(.improvement))
        #expect(cases.contains(.bugReport))
        #expect(cases.contains(.other))
    }

    @Test("RequestCategory raw values are correct")
    func testRequestCategoryRawValues() {
        #expect(RequestCategory.newFeature.rawValue == "new_feature")
        #expect(RequestCategory.improvement.rawValue == "improvement")
        #expect(RequestCategory.bugReport.rawValue == "bug_report")
        #expect(RequestCategory.other.rawValue == "other")
    }

    @Test("RequestCategory iconNames are non-empty")
    func testRequestCategoryIcons() {
        for category in RequestCategory.allCases {
            #expect(!category.iconName.isEmpty, "Icon for \(category.rawValue) should not be empty")
        }
    }

    @Test("RequestCategory specific icons are correct")
    func testRequestCategorySpecificIcons() {
        #expect(RequestCategory.newFeature.iconName == "lightbulb.fill")
        #expect(RequestCategory.improvement.iconName == "arrow.up.circle.fill")
        #expect(RequestCategory.bugReport.iconName == "ladybug.fill")
        #expect(RequestCategory.other.iconName == "ellipsis.circle.fill")
    }

    @Test("RequestCategory is Codable round-trip")
    func testRequestCategoryCodable() throws {
        for category in RequestCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(RequestCategory.self, from: data)
            #expect(decoded == category)
        }
    }

    // MARK: - RequestStatus

    @Test("RequestStatus has all 5 cases")
    func testRequestStatusCases() {
        let cases = RequestStatus.allCases
        #expect(cases.count == 5)
        #expect(cases.contains(.pending))
        #expect(cases.contains(.underReview))
        #expect(cases.contains(.planned))
        #expect(cases.contains(.completed))
        #expect(cases.contains(.declined))
    }

    @Test("RequestStatus raw values are correct")
    func testRequestStatusRawValues() {
        #expect(RequestStatus.pending.rawValue == "pending")
        #expect(RequestStatus.underReview.rawValue == "under_review")
        #expect(RequestStatus.planned.rawValue == "planned")
        #expect(RequestStatus.completed.rawValue == "completed")
        #expect(RequestStatus.declined.rawValue == "declined")
    }

    @Test("RequestStatus iconNames are non-empty")
    func testRequestStatusIcons() {
        for status in RequestStatus.allCases {
            #expect(!status.iconName.isEmpty, "Icon for \(status.rawValue) should not be empty")
        }
    }

    @Test("RequestStatus specific icons are correct")
    func testRequestStatusSpecificIcons() {
        #expect(RequestStatus.pending.iconName == "clock.fill")
        #expect(RequestStatus.underReview.iconName == "eye.fill")
        #expect(RequestStatus.planned.iconName == "calendar.badge.checkmark")
        #expect(RequestStatus.completed.iconName == "checkmark.circle.fill")
        #expect(RequestStatus.declined.iconName == "xmark.circle.fill")
    }

    @Test("RequestStatus colors are assigned")
    func testRequestStatusColors() {
        // Just verify they don't crash - Color values can't be easily compared
        for status in RequestStatus.allCases {
            let _ = status.color
        }
    }

    @Test("RequestStatus is Codable round-trip")
    func testRequestStatusCodable() throws {
        for status in RequestStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(RequestStatus.self, from: data)
            #expect(decoded == status)
        }
    }

    // MARK: - displayName

    @Test("RequestCategory displayName returns non-empty for all cases with en")
    func testRequestCategoryDisplayNameNonEmpty() {
        for category in RequestCategory.allCases {
            let name = category.displayName(language: "en")
            #expect(!name.isEmpty, "displayName for \(category.rawValue) should not be empty")
        }
    }

    @Test("RequestStatus displayName returns non-empty for all cases with en")
    func testRequestStatusDisplayNameNonEmpty() {
        for status in RequestStatus.allCases {
            let name = status.displayName(language: "en")
            #expect(!name.isEmpty, "displayName for \(status.rawValue) should not be empty")
        }
    }

    // MARK: - RequestStatus Equatable (used by filter)

    @Test("RequestStatus equality works correctly for filtering")
    func testRequestStatusEquality() {
        #expect(RequestStatus.pending == RequestStatus.pending)
        #expect(RequestStatus.pending != RequestStatus.completed)
        #expect(RequestStatus.underReview != RequestStatus.planned)
        #expect(RequestStatus.declined == RequestStatus.declined)
    }
}
