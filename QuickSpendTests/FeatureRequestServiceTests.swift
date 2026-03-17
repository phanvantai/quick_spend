import Testing
import Foundation
@testable import QuickSpend

// MARK: - Mock Store

/// In-memory mock that never touches Firestore. Tracks all calls for assertions.
final class MockFeatureRequestStore: FeatureRequestStore, @unchecked Sendable {
    var storedRequests: [FeatureRequest] = []
    var shouldThrow = false
    var fetchCallCount = 0
    var submitCallCount = 0
    var deleteCallCount = 0
    var updateStatusCallCount = 0
    var lastDeletedId: String?
    var lastUpdatedId: String?
    var lastUpdatedStatus: RequestStatus?
    var lastUpdatedResponse: String?

    func fetchRequests() async throws -> [FeatureRequest] {
        fetchCallCount += 1
        if shouldThrow { throw MockError.forced }
        return storedRequests
    }

    func submitRequest(_ request: FeatureRequest) async throws {
        submitCallCount += 1
        if shouldThrow { throw MockError.forced }
        storedRequests.append(request)
    }

    func deleteRequest(requestId: String) async throws {
        deleteCallCount += 1
        lastDeletedId = requestId
        if shouldThrow { throw MockError.forced }
        storedRequests.removeAll { $0.id == requestId }
    }

    func updateRequestStatus(requestId: String, newStatus: RequestStatus, response: String?) async throws {
        updateStatusCallCount += 1
        lastUpdatedId = requestId
        lastUpdatedStatus = newStatus
        lastUpdatedResponse = response
        if shouldThrow { throw MockError.forced }
        if let index = storedRequests.firstIndex(where: { $0.id == requestId }) {
            let old = storedRequests[index]
            storedRequests[index] = FeatureRequest(
                id: old.id, userId: old.userId, title: old.title,
                description: old.description, category: old.category,
                status: newStatus, createdAt: old.createdAt, updatedAt: .now,
                appVersion: old.appVersion, language: old.language,
                adminResponse: response ?? old.adminResponse,
                priority: old.priority
            )
        }
    }

    enum MockError: Error, LocalizedError {
        case forced
        var errorDescription: String? { "Mock error" }
    }
}

// MARK: - Tests

@Suite("FeatureRequestService Tests")
@MainActor
struct FeatureRequestServiceTests {

    // MARK: - Test Data Helpers

    private func makeTestDefaults() -> UserDefaults {
        let suiteName = "test.featurerequest.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    private func makeMockStore() -> MockFeatureRequestStore {
        MockFeatureRequestStore()
    }

    private func makeService(
        defaults: UserDefaults? = nil,
        store: MockFeatureRequestStore? = nil
    ) -> (FeatureRequestService, MockFeatureRequestStore) {
        let mockStore = store ?? makeMockStore()
        let service = FeatureRequestService(
            defaults: defaults ?? makeTestDefaults(),
            store: mockStore
        )
        return (service, mockStore)
    }

    private func makeSampleRequest(
        id: String = "req_1",
        userId: String = "user_1",
        title: String = "Test Feature",
        status: RequestStatus = .pending,
        priority: Int = 0
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
            adminResponse: nil,
            priority: priority
        )
    }

    // MARK: - Initial State

    @Test("Initial state has empty requests")
    func testInitialRequestsEmpty() {
        let (service, _) = makeService()
        #expect(service.requests.isEmpty)
    }

    @Test("Initial state is not loading")
    func testInitialIsNotLoading() {
        let (service, _) = makeService()
        #expect(service.isLoading == false)
    }

    @Test("Initial state has no error message")
    func testInitialNoErrorMessage() {
        let (service, _) = makeService()
        #expect(service.errorMessage == nil)
    }

    // MARK: - currentUserId

    @Test("currentUserId returns a non-empty string")
    func testCurrentUserIdNonEmpty() {
        let (service, _) = makeService()
        #expect(!service.currentUserId.isEmpty)
    }

    @Test("currentUserId returns consistent value across calls")
    func testCurrentUserIdConsistent() {
        let (service, _) = makeService()
        let id1 = service.currentUserId
        let id2 = service.currentUserId
        #expect(id1 == id2)
    }

    @Test("currentUserId is a valid UUID string")
    func testCurrentUserIdIsValidUUID() {
        let (service, _) = makeService()
        let uuid = UUID(uuidString: service.currentUserId)
        #expect(uuid != nil, "currentUserId should be a valid UUID string")
    }

    // MARK: - myRequests with Injected Data

    @Test("myRequests returns empty when no requests exist")
    func testMyRequestsEmptyWhenNoRequests() {
        let (service, _) = makeService()
        #expect(service.myRequests().isEmpty)
    }

    @Test("myRequests filters only requests matching currentUserId")
    func testMyRequestsFiltersCorrectly() {
        let (service, _) = makeService()
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
        let (service, _) = makeService()
        let otherRequest1 = makeSampleRequest(id: "req_1", userId: "other_user_1")
        let otherRequest2 = makeSampleRequest(id: "req_2", userId: "other_user_2")

        service._setRequests([otherRequest1, otherRequest2])

        #expect(service.myRequests().isEmpty)
    }

    @Test("myRequests returns all when all requests match currentUserId")
    func testMyRequestsReturnsAllWhenAllMatch() {
        let (service, _) = makeService()
        let myUserId = service.currentUserId
        let req1 = makeSampleRequest(id: "req_1", userId: myUserId, title: "Feature 1")
        let req2 = makeSampleRequest(id: "req_2", userId: myUserId, title: "Feature 2")

        service._setRequests([req1, req2])

        #expect(service.myRequests().count == 2)
    }

    // MARK: - _setRequests

    @Test("_setRequests replaces existing requests")
    func testSetRequestsReplaces() {
        let (service, _) = makeService()
        let req1 = makeSampleRequest(id: "req_1")
        let req2 = makeSampleRequest(id: "req_2")

        service._setRequests([req1])
        #expect(service.requests.count == 1)

        service._setRequests([req1, req2])
        #expect(service.requests.count == 2)
    }

    @Test("_setRequests with empty array clears requests")
    func testSetRequestsClears() {
        let (service, _) = makeService()
        service._setRequests([makeSampleRequest()])
        #expect(service.requests.count == 1)

        service._setRequests([])
        #expect(service.requests.isEmpty)
    }

    // MARK: - _removeLocalRequest

    @Test("_removeLocalRequest removes the correct request by ID")
    func testRemoveLocalRequestById() {
        let (service, _) = makeService()
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
        let (service, _) = makeService()
        let req = makeSampleRequest(id: "req_1")

        service._setRequests([req])
        service._removeLocalRequest(requestId: "nonexistent")

        #expect(service.requests.count == 1)
        #expect(service.requests.first?.id == "req_1")
    }

    @Test("_removeLocalRequest on empty requests does nothing")
    func testRemoveLocalRequestEmpty() {
        let (service, _) = makeService()
        service._removeLocalRequest(requestId: "req_1")
        #expect(service.requests.isEmpty)
    }

    // MARK: - fetchRequests (Mock Store)

    @Test("fetchRequests populates requests from mock store")
    func testFetchRequestsFromMockStore() async {
        let (service, mockStore) = makeService()
        let req = makeSampleRequest(id: "req_1", title: "From Store")
        mockStore.storedRequests = [req]

        await service.fetchRequests()

        #expect(service.requests.count == 1)
        #expect(service.requests.first?.title == "From Store")
        #expect(service.isLoading == false)
        #expect(mockStore.fetchCallCount == 1)
    }

    @Test("fetchRequests sets errorMessage on store error")
    func testFetchRequestsSetsError() async {
        let (service, mockStore) = makeService()
        mockStore.shouldThrow = true

        await service.fetchRequests()

        #expect(service.isLoading == false)
        #expect(service.errorMessage != nil)
    }

    @Test("fetchRequests clears previous requests on new fetch")
    func testFetchRequestsClearsPrevious() async {
        let (service, mockStore) = makeService()
        mockStore.storedRequests = [makeSampleRequest(id: "req_1")]
        await service.fetchRequests()
        #expect(service.requests.count == 1)

        mockStore.storedRequests = []
        await service.fetchRequests()
        #expect(service.requests.isEmpty)
    }

    // MARK: - submitRequest (Mock Store)

    @Test("submitRequest adds request to mock store and returns true")
    func testSubmitRequestSuccess() async {
        let (service, mockStore) = makeService()

        let result = await service.submitRequest(
            title: "Test Feature",
            description: "A test feature request",
            category: .newFeature,
            language: "en"
        )

        #expect(result == true)
        #expect(service.isLoading == false)
        #expect(mockStore.submitCallCount == 1)
        #expect(mockStore.storedRequests.count == 1)
        #expect(mockStore.storedRequests.first?.title == "Test Feature")
        // Service should have re-fetched after submit
        #expect(service.requests.count == 1)
    }

    @Test("submitRequest returns false on store error")
    func testSubmitRequestFailure() async {
        let (service, mockStore) = makeService()
        mockStore.shouldThrow = true

        let result = await service.submitRequest(
            title: "Feature",
            description: "Description",
            category: .improvement,
            language: "vi"
        )

        #expect(result == false)
        #expect(service.isLoading == false)
        #expect(service.errorMessage != nil)
    }

    @Test("submitRequest uses currentUserId as the request userId")
    func testSubmitRequestUsesCurrentUserId() async {
        let (service, mockStore) = makeService()

        _ = await service.submitRequest(
            title: "My Feature",
            description: "Desc",
            category: .newFeature,
            language: "en"
        )

        #expect(mockStore.storedRequests.first?.userId == service.currentUserId)
    }

    @Test("submitRequest sets priority 0 for free users (isPremium false)")
    func testSubmitRequestPriorityFreeUser() async {
        let (service, mockStore) = makeService()

        _ = await service.submitRequest(
            title: "Free Feature",
            description: "Desc",
            category: .newFeature,
            language: "en",
            isPremium: false
        )

        #expect(mockStore.storedRequests.first?.priority == 0)
    }

    @Test("submitRequest sets priority 1 for premium users (isPremium true)")
    func testSubmitRequestPriorityPremiumUser() async {
        let (service, mockStore) = makeService()

        _ = await service.submitRequest(
            title: "Premium Feature",
            description: "Desc",
            category: .newFeature,
            language: "en",
            isPremium: true
        )

        #expect(mockStore.storedRequests.first?.priority == 1)
    }

    @Test("submitRequest defaults to priority 0 when isPremium not specified")
    func testSubmitRequestDefaultPriority() async {
        let (service, mockStore) = makeService()

        _ = await service.submitRequest(
            title: "Default Priority",
            description: "Desc",
            category: .newFeature,
            language: "en"
        )

        #expect(mockStore.storedRequests.first?.priority == 0)
    }

    // MARK: - deleteRequest (Mock Store)

    @Test("deleteRequest removes from mock store and returns true")
    func testDeleteRequestSuccess() async {
        let (service, mockStore) = makeService()
        let req = makeSampleRequest(id: "req_to_delete")
        mockStore.storedRequests = [req]

        let result = await service.deleteRequest(requestId: "req_to_delete")

        #expect(result == true)
        #expect(service.isLoading == false)
        #expect(mockStore.deleteCallCount == 1)
        #expect(mockStore.lastDeletedId == "req_to_delete")
        #expect(mockStore.storedRequests.isEmpty)
        #expect(service.requests.isEmpty)
    }

    @Test("deleteRequest returns false on store error")
    func testDeleteRequestFailure() async {
        let (service, mockStore) = makeService()
        mockStore.shouldThrow = true

        let result = await service.deleteRequest(requestId: "req_1")

        #expect(result == false)
        #expect(service.isLoading == false)
        #expect(service.errorMessage != nil)
    }

    // MARK: - updateRequestStatus (Mock Store)

    @Test("updateRequestStatus updates in mock store and returns true")
    func testUpdateRequestStatusSuccess() async {
        let (service, mockStore) = makeService()
        let req = makeSampleRequest(id: "req_1", status: .pending)
        mockStore.storedRequests = [req]

        let result = await service.updateRequestStatus(
            requestId: "req_1",
            newStatus: .completed,
            response: "Done"
        )

        #expect(result == true)
        #expect(service.isLoading == false)
        #expect(mockStore.updateStatusCallCount == 1)
        #expect(mockStore.lastUpdatedId == "req_1")
        #expect(mockStore.lastUpdatedStatus == .completed)
        #expect(mockStore.lastUpdatedResponse == "Done")
        #expect(service.requests.first?.status == .completed)
    }

    @Test("updateRequestStatus returns false on store error")
    func testUpdateRequestStatusFailure() async {
        let (service, mockStore) = makeService()
        mockStore.shouldThrow = true

        let result = await service.updateRequestStatus(
            requestId: "req_1",
            newStatus: .planned
        )

        #expect(result == false)
        #expect(service.isLoading == false)
        #expect(service.errorMessage != nil)
    }

    @Test("updateRequestStatus without response parameter works")
    func testUpdateRequestStatusWithoutResponse() async {
        let (service, mockStore) = makeService()
        let req = makeSampleRequest(id: "req_1", status: .pending)
        mockStore.storedRequests = [req]

        let result = await service.updateRequestStatus(
            requestId: "req_1",
            newStatus: .planned
        )

        #expect(result == true)
        #expect(mockStore.lastUpdatedResponse == nil)
    }

    // MARK: - Multiple Operations

    @Test("Multiple sequential operations work correctly with mock store")
    func testMultipleSequentialOperations() async {
        let (service, mockStore) = makeService()

        // Fetch (empty)
        await service.fetchRequests()
        #expect(service.requests.isEmpty)

        // Submit
        let submitted = await service.submitRequest(
            title: "Feature 1",
            description: "Description 1",
            category: .bugReport,
            language: "en"
        )
        #expect(submitted == true)
        #expect(service.requests.count == 1)

        // Update status
        let reqId = mockStore.storedRequests.first!.id
        let updated = await service.updateRequestStatus(
            requestId: reqId,
            newStatus: .underReview
        )
        #expect(updated == true)
        #expect(service.requests.first?.status == .underReview)

        // Delete
        let deleted = await service.deleteRequest(requestId: reqId)
        #expect(deleted == true)
        #expect(service.requests.isEmpty)

        #expect(service.isLoading == false)
    }

    // MARK: - requestsByStatus

    @Test("requestsByStatus returns empty when no requests exist")
    func testRequestsByStatusEmptyWhenNoRequests() {
        let (service, _) = makeService()
        #expect(service.requestsByStatus(.pending).isEmpty)
    }

    @Test("requestsByStatus filters by pending status")
    func testRequestsByStatusFiltersPending() {
        let (service, _) = makeService()
        let pending1 = makeSampleRequest(id: "req_1", status: .pending)
        let review = makeSampleRequest(id: "req_2", status: .underReview)
        let pending2 = makeSampleRequest(id: "req_3", status: .pending)
        let completed = makeSampleRequest(id: "req_4", status: .completed)

        service._setRequests([pending1, review, pending2, completed])

        let result = service.requestsByStatus(.pending)
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.status == .pending })
    }

    @Test("requestsByStatus filters by completed status")
    func testRequestsByStatusFiltersCompleted() {
        let (service, _) = makeService()
        let pending = makeSampleRequest(id: "req_1", status: .pending)
        let completed1 = makeSampleRequest(id: "req_2", status: .completed)
        let completed2 = makeSampleRequest(id: "req_3", status: .completed)

        service._setRequests([pending, completed1, completed2])

        let result = service.requestsByStatus(.completed)
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.status == .completed })
    }

    @Test("requestsByStatus returns empty when no matching status")
    func testRequestsByStatusReturnsEmptyWhenNoMatch() {
        let (service, _) = makeService()
        let pending = makeSampleRequest(id: "req_1", status: .pending)
        let review = makeSampleRequest(id: "req_2", status: .underReview)

        service._setRequests([pending, review])

        #expect(service.requestsByStatus(.declined).isEmpty)
    }

    @Test("requestsByStatus works for all status cases")
    func testRequestsByStatusAllCases() {
        let (service, _) = makeService()
        let requests = RequestStatus.allCases.enumerated().map { index, status in
            makeSampleRequest(id: "req_\(index)", status: status)
        }

        service._setRequests(requests)

        for status in RequestStatus.allCases {
            let filtered = service.requestsByStatus(status)
            #expect(filtered.count == 1)
            #expect(filtered.first?.status == status)
        }
    }
}
