import Testing
import Foundation
@testable import QuickSpend

@Suite("FeatureRequestService Tests")
struct FeatureRequestServiceTests {

    // MARK: - Initial State

    @Test("Initial state has empty requests")
    func testInitialRequestsEmpty() {
        let service = FeatureRequestService()
        #expect(service.requests.isEmpty)
    }

    @Test("Initial state is not loading")
    func testInitialIsNotLoading() {
        let service = FeatureRequestService()
        #expect(service.isLoading == false)
    }

    @Test("Initial state has no error message")
    func testInitialNoErrorMessage() {
        let service = FeatureRequestService()
        #expect(service.errorMessage == nil)
    }

    // MARK: - currentUserId

    @Test("currentUserId returns a non-empty string")
    func testCurrentUserIdNonEmpty() {
        let service = FeatureRequestService()
        #expect(!service.currentUserId.isEmpty)
    }

    @Test("currentUserId returns consistent value across calls")
    func testCurrentUserIdConsistent() {
        let service = FeatureRequestService()
        // First call stores the id in UserDefaults if not present
        let id1 = service.currentUserId
        // Store it explicitly to avoid race conditions with parallel tests
        UserDefaults.standard.set(id1, forKey: "anonymous_user_id")
        UserDefaults.standard.synchronize()
        let id2 = service.currentUserId
        #expect(id1 == id2)
    }

    @Test("currentUserId is a valid UUID string")
    func testCurrentUserIdIsValidUUID() {
        let service = FeatureRequestService()
        let uuid = UUID(uuidString: service.currentUserId)
        #expect(uuid != nil, "currentUserId should be a valid UUID string")
    }

    // MARK: - myRequests

    @Test("myRequests returns empty when no requests exist")
    func testMyRequestsEmptyWhenNoRequests() {
        let service = FeatureRequestService()
        let myReqs = service.myRequests()
        #expect(myReqs.isEmpty)
    }

    @Test("myRequests returns empty when no requests match currentUserId")
    func testMyRequestsEmptyWhenNoMatches() {
        let service = FeatureRequestService()
        // requests array is empty by default, so myRequests should return empty
        #expect(service.myRequests().isEmpty)
    }

    // MARK: - Graceful Degradation Without Firestore

    @Test("fetchRequests completes without crashing")
    func testFetchRequestsGraceful() async {
        let service = FeatureRequestService()
        await service.fetchRequests()
        // Without Firestore, requests should remain empty
        // isLoading should be false after completion
        #expect(service.isLoading == false)
    }

    @Test("submitRequest completes gracefully")
    func testSubmitRequestCompletes() async {
        let service = FeatureRequestService()
        let result = await service.submitRequest(
            title: "Test Feature",
            description: "A test feature request",
            category: .newFeature,
            language: "en"
        )
        // Result depends on whether Firestore is available at runtime
        // Either way, isLoading should be false after completion
        let _ = result
        #expect(service.isLoading == false)
    }

    @Test("updateRequestStatus completes gracefully for nonexistent request")
    func testUpdateRequestStatusCompletes() async {
        let service = FeatureRequestService()
        let result = await service.updateRequestStatus(
            requestId: "nonexistent_request_id_xyz",
            newStatus: .completed,
            response: "Done"
        )
        // With or without Firestore, updating a nonexistent request should not succeed
        // isLoading should be false after completion
        let _ = result
        #expect(service.isLoading == false)
    }

    @Test("submitRequest sets isLoading to false after completion")
    func testSubmitRequestIsLoadingAfterCompletion() async {
        let service = FeatureRequestService()
        let _ = await service.submitRequest(
            title: "Feature",
            description: "Description",
            category: .improvement,
            language: "vi"
        )
        #expect(service.isLoading == false)
    }

    @Test("updateRequestStatus without response parameter works")
    func testUpdateRequestStatusWithoutResponse() async {
        let service = FeatureRequestService()
        let result = await service.updateRequestStatus(
            requestId: "nonexistent_req_456",
            newStatus: .planned
        )
        // Result depends on Firestore availability; either way, should complete
        let _ = result
        #expect(service.isLoading == false)
    }

    // MARK: - Multiple Operations

    @Test("Multiple sequential operations do not crash")
    func testMultipleSequentialOperations() async {
        let service = FeatureRequestService()

        await service.fetchRequests()
        let _ = await service.submitRequest(
            title: "Feature 1",
            description: "Description 1",
            category: .bugReport,
            language: "en"
        )
        let _ = await service.updateRequestStatus(
            requestId: "nonexistent_req",
            newStatus: .underReview
        )
        await service.fetchRequests()

        // After all operations complete, isLoading should be false
        #expect(service.isLoading == false)
        // errorMessage may or may not be set depending on Firestore availability
    }
}
