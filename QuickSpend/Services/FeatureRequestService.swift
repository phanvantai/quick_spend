import Foundation

// MARK: - Store Protocol

/// Abstracts the persistence backend so tests can inject a mock instead of hitting real Firestore.
protocol FeatureRequestStore: Sendable {
    func fetchRequests() async throws -> [FeatureRequest]
    func submitRequest(_ request: FeatureRequest) async throws
    func deleteRequest(requestId: String) async throws
    func updateRequestStatus(requestId: String, newStatus: RequestStatus, response: String?) async throws
}

// MARK: - Service

/// Service for submitting and fetching feature requests
@Observable
final class FeatureRequestService {
    private(set) var requests: [FeatureRequest] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private var storeAvailable = true
    private let defaults: UserDefaults
    private let store: FeatureRequestStore?

    init(defaults: UserDefaults = .standard, store: FeatureRequestStore? = nil) {
        self.defaults = defaults
        if let store {
            self.store = store
        } else {
            #if canImport(FirebaseFirestore)
            self.store = FirestoreFeatureRequestStore()
            #else
            self.store = nil
            #endif
        }
    }

    var currentUserId: String {
        if let existingId = defaults.string(forKey: "anonymous_user_id") {
            return existingId
        }
        let newId = UUID().uuidString
        defaults.set(newId, forKey: "anonymous_user_id")
        return newId
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    // MARK: - Fetch All Requests

    func fetchRequests() async {
        guard storeAvailable, let store else {
            print("[FeatureRequest] Store not available")
            return
        }
        isLoading = true
        errorMessage = nil

        do {
            requests = try await store.fetchRequests()
            isLoading = false
        } catch {
            handleError(error)
        }
    }

    // MARK: - Submit New Request

    func submitRequest(
        title: String,
        description: String,
        category: RequestCategory,
        language: String,
        isPremium: Bool = false
    ) async -> Bool {
        guard storeAvailable, let store else { return false }
        isLoading = true
        errorMessage = nil

        let request = FeatureRequest(
            id: UUID().uuidString,
            userId: currentUserId,
            title: title,
            description: description,
            category: category,
            status: .pending,
            createdAt: .now,
            updatedAt: .now,
            appVersion: appVersion,
            language: language,
            adminResponse: nil,
            priority: isPremium ? 1 : 0
        )

        do {
            try await store.submitRequest(request)
            requests = try await store.fetchRequests()
            isLoading = false
            return true
        } catch {
            handleError(error)
            return false
        }
    }

    // MARK: - Update Request Status (Admin)

    func updateRequestStatus(requestId: String, newStatus: RequestStatus, response: String? = nil) async -> Bool {
        guard storeAvailable, let store else { return false }
        isLoading = true
        errorMessage = nil

        do {
            try await store.updateRequestStatus(requestId: requestId, newStatus: newStatus, response: response)
            requests = try await store.fetchRequests()
            isLoading = false
            return true
        } catch {
            handleError(error)
            return false
        }
    }

    // MARK: - Delete Request (Admin)

    func deleteRequest(requestId: String) async -> Bool {
        guard storeAvailable, let store else { return false }
        isLoading = true
        errorMessage = nil

        do {
            try await store.deleteRequest(requestId: requestId)
            requests = try await store.fetchRequests()
            isLoading = false
            return true
        } catch {
            handleError(error)
            return false
        }
    }

    // MARK: - Filter Helpers

    func myRequests() -> [FeatureRequest] {
        requests.filter { $0.userId == currentUserId }
    }

    func requestsByStatus(_ status: RequestStatus) -> [FeatureRequest] {
        requests.filter { $0.status == status }
    }

    // MARK: - Test Helpers

    /// Inject requests directly for unit testing without Firestore
    func _setRequests(_ newRequests: [FeatureRequest]) {
        requests = newRequests
    }

    /// Remove a request from the local array by ID (used for testing delete logic)
    func _removeLocalRequest(requestId: String) {
        requests.removeAll { $0.id == requestId }
    }

    // MARK: - Private

    private func handleError(_ error: Error) {
        let errorStr = error.localizedDescription
        if errorStr.contains("NOT_FOUND") || errorStr.contains("does not exist") {
            storeAvailable = false
            print("[FeatureRequest] Store not configured - disabling")
        }
        errorMessage = errorStr
        isLoading = false
        print("[FeatureRequest] Error: \(errorStr)")
    }
}

// MARK: - Firestore Implementation

#if canImport(FirebaseFirestore)
import FirebaseFirestore

/// Real Firestore-backed store used in production.
struct FirestoreFeatureRequestStore: FeatureRequestStore {
    private var db: Firestore { Firestore.firestore() }
    private var collection: CollectionReference {
        db.collection(AppConstants.featureRequestsCollection)
    }

    func fetchRequests() async throws -> [FeatureRequest] {
        let snapshot = try await collection
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let title = data["title"] as? String,
                  let description = data["description"] as? String,
                  let categoryRaw = data["category"] as? String,
                  let statusRaw = data["status"] as? String
            else { return nil }

            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

            return FeatureRequest(
                id: doc.documentID,
                userId: data["userId"] as? String ?? "",
                title: title,
                description: description,
                category: RequestCategory(rawValue: categoryRaw) ?? .other,
                status: RequestStatus(rawValue: statusRaw) ?? .pending,
                createdAt: createdAt,
                updatedAt: updatedAt,
                appVersion: data["appVersion"] as? String ?? "unknown",
                language: data["language"] as? String ?? "en",
                adminResponse: data["adminResponse"] as? String,
                priority: data["priority"] as? Int ?? 0
            )
        }
    }

    func submitRequest(_ request: FeatureRequest) async throws {
        try await collection.addDocument(data: [
            "userId": request.userId,
            "title": request.title,
            "description": request.description,
            "category": request.category.rawValue,
            "status": request.status.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "appVersion": request.appVersion,
            "language": request.language,
            "priority": request.priority,
        ])
        print("[FeatureRequest] Submitted: \(request.title)")
    }

    func deleteRequest(requestId: String) async throws {
        try await collection.document(requestId).delete()
        print("[FeatureRequest] Deleted request: \(requestId)")
    }

    func updateRequestStatus(requestId: String, newStatus: RequestStatus, response: String?) async throws {
        var updateData: [String: Any] = [
            "status": newStatus.rawValue,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        if let response, !response.isEmpty {
            updateData["adminResponse"] = response
        }
        try await collection.document(requestId).updateData(updateData)
        print("[FeatureRequest] Updated status of \(requestId) to \(newStatus.rawValue)")
    }
}
#endif
