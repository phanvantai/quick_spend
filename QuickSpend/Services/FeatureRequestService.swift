import Foundation

/// Service for submitting and fetching feature requests from Firestore
@Observable
final class FeatureRequestService {
    private(set) var requests: [FeatureRequest] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private var firestoreAvailable = true
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var currentUserId: String {
        if let existingId = defaults.string(forKey: "anonymous_user_id") {
            return existingId
        }
        let newId = UUID().uuidString
        defaults.set(newId, forKey: "anonymous_user_id")
        return newId
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    // MARK: - Fetch All Requests

    func fetchRequests() async {
        guard firestoreAvailable else { return }
        isLoading = true
        errorMessage = nil

        #if canImport(FirebaseFirestore)
        await _fetchFromFirestore()
        #else
        print("[FeatureRequest] Firestore not available")
        isLoading = false
        #endif
    }

    // MARK: - Submit New Request

    func submitRequest(
        title: String,
        description: String,
        category: RequestCategory,
        language: String
    ) async -> Bool {
        guard firestoreAvailable else { return false }
        isLoading = true
        errorMessage = nil

        #if canImport(FirebaseFirestore)
        let success = await _submitToFirestore(
            title: title,
            description: description,
            category: category,
            language: language
        )
        isLoading = false
        return success
        #else
        print("[FeatureRequest] Firestore not available")
        isLoading = false
        return false
        #endif
    }

    // MARK: - Update Request Status (Admin)

    func updateRequestStatus(requestId: String, newStatus: RequestStatus, response: String? = nil) async -> Bool {
        guard firestoreAvailable else { return false }
        isLoading = true
        errorMessage = nil

        #if canImport(FirebaseFirestore)
        let success = await _updateStatusInFirestore(requestId: requestId, newStatus: newStatus, response: response)
        isLoading = false
        return success
        #else
        print("[FeatureRequest] Firestore not available")
        isLoading = false
        return false
        #endif
    }

    // MARK: - Delete Request (Admin)

    func deleteRequest(requestId: String) async -> Bool {
        guard firestoreAvailable else { return false }
        isLoading = true
        errorMessage = nil

        #if canImport(FirebaseFirestore)
        let success = await _deleteFromFirestore(requestId: requestId)
        isLoading = false
        return success
        #else
        print("[FeatureRequest] Firestore not available")
        isLoading = false
        return false
        #endif
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
}

// MARK: - Firestore Integration

#if canImport(FirebaseFirestore)
import FirebaseFirestore

extension FeatureRequestService {
    func _fetchFromFirestore() async {
        do {
            let snapshot = try await Firestore.firestore()
                .collection(AppConstants.featureRequestsCollection)
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()

            requests = snapshot.documents.compactMap { doc in
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
                    adminResponse: data["adminResponse"] as? String
                )
            }
            isLoading = false
            print("[FeatureRequest] Fetched \(requests.count) requests")
        } catch {
            let errorStr = error.localizedDescription
            if errorStr.contains("NOT_FOUND") || errorStr.contains("does not exist") {
                firestoreAvailable = false
                print("[FeatureRequest] Firestore not configured - disabling")
            }
            errorMessage = errorStr
            isLoading = false
            print("[FeatureRequest] Fetch error: \(errorStr)")
        }
    }

    func _submitToFirestore(
        title: String,
        description: String,
        category: RequestCategory,
        language: String
    ) async -> Bool {
        do {
            try await Firestore.firestore()
                .collection(AppConstants.featureRequestsCollection)
                .addDocument(data: [
                    "userId": currentUserId,
                    "title": title,
                    "description": description,
                    "category": category.rawValue,
                    "status": RequestStatus.pending.rawValue,
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp(),
                    "appVersion": appVersion,
                    "language": language,
                ])
            print("[FeatureRequest] Submitted: \(title)")
            await _fetchFromFirestore()
            return true
        } catch {
            let errorStr = error.localizedDescription
            if errorStr.contains("NOT_FOUND") || errorStr.contains("does not exist") {
                firestoreAvailable = false
                print("[FeatureRequest] Firestore not configured - disabling")
            }
            errorMessage = errorStr
            print("[FeatureRequest] Submit error: \(errorStr)")
            return false
        }
    }
    func _deleteFromFirestore(requestId: String) async -> Bool {
        do {
            try await Firestore.firestore()
                .collection(AppConstants.featureRequestsCollection)
                .document(requestId)
                .delete()
            print("[FeatureRequest] Deleted request: \(requestId)")
            await _fetchFromFirestore()
            return true
        } catch {
            let errorStr = error.localizedDescription
            errorMessage = errorStr
            print("[FeatureRequest] Delete error: \(errorStr)")
            return false
        }
    }

    func _updateStatusInFirestore(requestId: String, newStatus: RequestStatus, response: String?) async -> Bool {
        do {
            var updateData: [String: Any] = [
                "status": newStatus.rawValue,
                "updatedAt": FieldValue.serverTimestamp(),
            ]
            if let response, !response.isEmpty {
                updateData["adminResponse"] = response
            }
            try await Firestore.firestore()
                .collection(AppConstants.featureRequestsCollection)
                .document(requestId)
                .updateData(updateData)
            print("[FeatureRequest] Updated status of \(requestId) to \(newStatus.rawValue)")
            await _fetchFromFirestore()
            return true
        } catch {
            let errorStr = error.localizedDescription
            errorMessage = errorStr
            print("[FeatureRequest] Update status error: \(errorStr)")
            return false
        }
    }
}
#endif
