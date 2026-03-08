import Testing
import Foundation
@testable import QuickSpend

@Suite("FeatureRequestService Tests")
struct FeatureRequestServiceTests {

    // MARK: - Test Data Helpers

    private func makeSampleRequest(
        id: String = "req_1",
        userId: String = "user_1",
        title: String = "Test Feature",
        status: RequestStatus = .pending
    ) -> FeatureRequest {
        FeatureRequest(
            id: id,
            userId: userId,
            title: title,
            description: "Test description",
            category: .newFeature,
            status: status,
            createdAt: .now,
            updatedAt: .now,
            appVersion: "1.0.0",
            language: "en",
            adminResponse: nil
        )
    }

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
        let id1 = service.currentUserId
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

    // MARK: - myRequests with Injected Data

    @Test("myRequests returns empty when no requests exist")
    func testMyRequestsEmptyWhenNoRequests() {
        let service = FeatureRequestService()
        #expect(service.myRequests().isEmpty)
    }

    @Test("myRequests filters only requests matching currentUserId")
    func testMyRequestsFiltersCorrectly() {
        let service = FeatureRequestService()
        let myUserId = service.currentUserId
        let myRequest = makeSampleRequest(id: "req_mine", userId: myUserId, title: "My Request")
        let otherRequest = makeSampleRequest(id: "req_other", userId: "other_user", title: "Other Request")

        service._setRequests([myRequest, otherRequest])

        let myReqs = service.myRequests()
        #expect(myReqs.count == 1)
        #expect(myReqs.first?.id == "req_mine")
    }

    @Test("myRequests returns empty when no requests match currentUserId")
    func testMyRequestsEmptyWhenNoMatch() {
        let service = FeatureRequestService()
        let otherRequest1 = makeSampleRequest(id: "req_1", userId: "other_user_1")
        let otherRequest2 = makeSampleRequest(id: "req_2", userId: "other_user_2")

        service._setRequests([otherRequest1, otherRequest2])

        #expect(service.myRequests().isEmpty)
    }

    @Test("myRequests returns all when all requests match currentUserId")
    func testMyRequestsReturnsAllWhenAllMatch() {
        let service = FeatureRequestService()
        let myUserId = service.currentUserId
        let req1 = makeSampleRequest(id: "req_1", userId: myUserId, title: "Feature 1")
        let req2 = makeSampleRequest(id: "req_2", userId: myUserId, title: "Feature 2")

        service._setRequests([req1, req2])

        #expect(service.myRequests().count == 2)
    }

    // MARK: - _setRequests

    @Test("_setRequests replaces existing requests")
    func testSetRequestsReplaces() {
        let service = FeatureRequestService()
        let req1 = makeSampleRequest(id: "req_1")
        let req2 = makeSampleRequest(id: "req_2")

        service._setRequests([req1])
        #expect(service.requests.count == 1)

        service._setRequests([req1, req2])
        #expect(service.requests.count == 2)
    }

    @Test("_setRequests with empty array clears requests")
    func testSetRequestsClears() {
        let service = FeatureRequestService()
        service._setRequests([makeSampleRequest()])
        #expect(service.requests.count == 1)

        service._setRequests([])
        #expect(service.requests.isEmpty)
    }

    // MARK: - _removeLocalRequest

    @Test("_removeLocalRequest removes the correct request by ID")
    func testRemoveLocalRequestById() {
        let service = FeatureRequestService()
        let req1 = makeSampleRequest(id: "req_1", title: "Keep")
        let req2 = makeSampleRequest(id: "req_2", title: "Remove")
        let req3 = makeSampleRequest(id: "req_3", title: "Keep Too")

        service._setRequests([req1, req2, req3])
        service._removeLocalRequest(requestId: "req_2")

        #expect(service.requests.count == 2)
        #expect(service.requests.contains { $0.id == "req_1" })
        #expect(service.requests.contains { $0.id == "req_3" })
        #expect(!service.requests.contains { $0.id == "req_2" })
    }

    @Test("_removeLocalRequest does nothing for nonexistent ID")
    func testRemoveLocalRequestNonexistent() {
        let service = FeatureRequestService()
        let req = makeSampleRequest(id: "req_1")

        service._setRequests([req])
        service._removeLocalRequest(requestId: "nonexistent")

        #expect(service.requests.count == 1)
        #expect(service.requests.first?.id == "req_1")
    }

    @Test("_removeLocalRequest on empty requests does nothing")
    func testRemoveLocalRequestEmpty() {
        let service = FeatureRequestService()
        service._removeLocalRequest(requestId: "req_1")
        #expect(service.requests.isEmpty)
    }

    // MARK: - Graceful Degradation Without Firestore

    @Test("fetchRequests completes without crashing")
    func testFetchRequestsGraceful() async {
        let service = FeatureRequestService()
        await service.fetchRequests()
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
        let _ = result
        #expect(service.isLoading == false)
    }

    @Test("deleteRequest completes gracefully for nonexistent request")
    func testDeleteRequestCompletes() async {
        let service = FeatureRequestService()
        let result = await service.deleteRequest(requestId: "nonexistent_request_id_delete")
        let _ = result
        #expect(service.isLoading == false)
    }

    @Test("deleteRequest sets isLoading to false after completion")
    func testDeleteRequestIsLoadingAfterCompletion() async {
        let service = FeatureRequestService()
        let _ = await service.deleteRequest(requestId: "nonexistent_req_789")
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
        let _ = await service.deleteRequest(requestId: "nonexistent_req_delete")
        await service.fetchRequests()

        #expect(service.isLoading == false)
    }
}
