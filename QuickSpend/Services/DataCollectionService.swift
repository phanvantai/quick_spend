import Foundation

/// Privacy-first opt-in ML training data collection
/// Collects anonymized expense parsing data for improving categorization
///
/// NOTE: Requires FirebaseFirestore SDK added via SPM. Until then,
/// data is not collected and the service reports unavailable.
@Observable
final class DataCollectionService {
    private let anonymousUserIdKey = "anonymous_user_id"
    private let defaults = UserDefaults.standard

    private(set) var anonymousUserId: String
    private var firestoreAvailable = true

    var hasConsent: Bool = false

    init() {
        // Load or create anonymous user ID
        if let existingId = UserDefaults.standard.string(forKey: "anonymous_user_id") {
            anonymousUserId = existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "anonymous_user_id")
            anonymousUserId = newId
        }
    }

    /// Log expense parsing data for training
    func logExpenseParsing(
        rawInput: String,
        description: String,
        amount: Double,
        predictedCategory: String,
        finalCategory: String,
        confidence: Double,
        language: String,
        inputMethod: String,
        parserUsed: String
    ) {
        guard hasConsent, firestoreAvailable else { return }

        #if canImport(FirebaseFirestore)
        _logToFirestore(collection: "training_data", data: [
            "rawInput": rawInput,
            "description": description,
            "amount": amount,
            "predictedCategory": predictedCategory,
            "finalCategory": finalCategory,
            "wasCorrected": predictedCategory != finalCategory,
            "confidence": confidence,
            "language": language,
            "inputMethod": inputMethod,
            "parserUsed": parserUsed,
            "userId": anonymousUserId,
            "appVersion": appVersion,
        ])
        #else
        print("[DataCollection] Firestore not available - skipping")
        #endif
    }

    /// Log category correction (gold data)
    func logCategoryCorrection(
        expenseId: String,
        rawInput: String,
        description: String,
        amount: Double,
        originalCategory: String,
        correctedCategory: String,
        language: String
    ) {
        guard hasConsent, firestoreAvailable else { return }

        #if canImport(FirebaseFirestore)
        _logToFirestore(collection: "user_corrections", data: [
            "expenseId": expenseId,
            "rawInput": rawInput,
            "description": description,
            "amount": amount,
            "originalCategory": originalCategory,
            "correctedCategory": correctedCategory,
            "language": language,
            "userId": anonymousUserId,
            "appVersion": appVersion,
        ])
        #else
        print("[DataCollection] Firestore not available - skipping")
        #endif
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
}

// MARK: - Firestore Integration

#if canImport(FirebaseFirestore)
import FirebaseFirestore

extension DataCollectionService {
    func _logToFirestore(collection: String, data: [String: Any]) {
        var mutableData = data
        mutableData["timestamp"] = FieldValue.serverTimestamp()

        Firestore.firestore().collection(collection).addDocument(data: mutableData) { [weak self] error in
            if let error {
                let errorStr = error.localizedDescription
                if errorStr.contains("NOT_FOUND") || errorStr.contains("does not exist") {
                    print("[DataCollection] Firestore not configured - disabling")
                    self?.firestoreAvailable = false
                } else {
                    print("[DataCollection] Error: \(errorStr)")
                }
            } else {
                print("[DataCollection] Logged to \(collection)")
            }
        }
    }
}
#endif
