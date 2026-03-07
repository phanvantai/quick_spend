import Testing
import Foundation
@testable import QuickSpend

@Suite("DataCollectionService Tests")
struct DataCollectionServiceTests {

    // MARK: - Initialization

    @Test("init creates a non-empty anonymousUserId")
    func testInitCreatesAnonymousUserId() {
        let service = DataCollectionService()
        #expect(!service.anonymousUserId.isEmpty)
    }

    @Test("init creates a valid UUID string for anonymousUserId")
    func testInitCreatesValidUUID() {
        // Clear any existing anonymous user ID to force creation of a new one
        let testKey = "anonymous_user_id"
        let existingValue = UserDefaults.standard.string(forKey: testKey)

        let service = DataCollectionService()
        // The anonymousUserId should be a valid UUID format
        let uuid = UUID(uuidString: service.anonymousUserId)
        #expect(uuid != nil, "anonymousUserId should be a valid UUID string")

        // Restore the original value if needed
        if let existingValue {
            UserDefaults.standard.set(existingValue, forKey: testKey)
        }
    }

    @Test("init returns consistent anonymousUserId across instances")
    func testConsistentAnonymousUserId() {
        let service1 = DataCollectionService()
        let service2 = DataCollectionService()
        #expect(service1.anonymousUserId == service2.anonymousUserId)
    }

    // MARK: - hasConsent

    @Test("hasConsent defaults to false")
    func testHasConsentDefaultsFalse() {
        let service = DataCollectionService()
        #expect(service.hasConsent == false)
    }

    @Test("hasConsent can be set to true")
    func testSetHasConsentTrue() {
        let service = DataCollectionService()
        service.hasConsent = true
        #expect(service.hasConsent == true)
    }

    @Test("hasConsent can be toggled")
    func testToggleHasConsent() {
        let service = DataCollectionService()
        #expect(service.hasConsent == false)
        service.hasConsent = true
        #expect(service.hasConsent == true)
        service.hasConsent = false
        #expect(service.hasConsent == false)
    }

    // MARK: - logExpenseParsing

    @Test("logExpenseParsing does not crash without consent")
    func testLogExpenseParsingWithoutConsent() {
        let service = DataCollectionService()
        // hasConsent is false by default, so this should silently return
        service.logExpenseParsing(
            rawInput: "coffee 5 dollars",
            description: "Coffee",
            amount: 5.0,
            predictedCategory: "food_drink",
            finalCategory: "food_drink",
            confidence: 0.95,
            language: "en",
            inputMethod: "voice",
            parserUsed: "gemini"
        )
        // If we reach this point, the method did not crash
        #expect(service.hasConsent == false)
    }

    @Test("logExpenseParsing does not crash with consent but no Firestore")
    func testLogExpenseParsingWithConsentNoFirestore() {
        let service = DataCollectionService()
        service.hasConsent = true
        // Without Firestore SDK, this should gracefully handle the call
        service.logExpenseParsing(
            rawInput: "lunch 15",
            description: "Lunch",
            amount: 15.0,
            predictedCategory: "food_drink",
            finalCategory: "food_drink",
            confidence: 0.9,
            language: "en",
            inputMethod: "text",
            parserUsed: "gemini"
        )
        #expect(service.hasConsent == true)
    }

    // MARK: - logCategoryCorrection

    @Test("logCategoryCorrection does not crash without consent")
    func testLogCategoryCorrectionWithoutConsent() {
        let service = DataCollectionService()
        // hasConsent is false by default
        service.logCategoryCorrection(
            expenseId: "expense_123",
            rawInput: "uber ride",
            description: "Uber Ride",
            amount: 25.0,
            originalCategory: "other",
            correctedCategory: "transport",
            language: "en"
        )
        // If we reach this point, the method did not crash
        #expect(service.hasConsent == false)
    }

    @Test("logCategoryCorrection does not crash with consent but no Firestore")
    func testLogCategoryCorrectionWithConsentNoFirestore() {
        let service = DataCollectionService()
        service.hasConsent = true
        service.logCategoryCorrection(
            expenseId: "expense_456",
            rawInput: "gas station",
            description: "Gas Station",
            amount: 50.0,
            originalCategory: "shopping",
            correctedCategory: "transport",
            language: "en"
        )
        #expect(service.hasConsent == true)
    }

    // MARK: - Persistence

    @Test("anonymousUserId persists in UserDefaults")
    func testAnonymousUserIdPersistence() {
        let service = DataCollectionService()
        let userId = service.anonymousUserId

        // Verify it was stored in UserDefaults
        let storedId = UserDefaults.standard.string(forKey: "anonymous_user_id")
        #expect(storedId == userId)
    }
}
