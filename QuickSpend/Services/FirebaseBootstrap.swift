import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
import DeviceCheck
#endif

/// Which App Check attestation provider this process should use.
///
/// Firebase AI Logic rejects Gemini requests without a valid App Check token
/// (enforced from 2026-11-02). Debug builds and the simulator cannot attest,
/// so they use the debug provider; register the token it logs on first launch
/// under Firebase Console → App Check → Apps → Manage debug tokens.
enum AppCheckProviderKind: Equatable {
    case debug
    case appAttest
    case deviceCheck

    static func resolve(isDebugBuild: Bool, isSimulator: Bool, isAppAttestSupported: Bool) -> AppCheckProviderKind {
        if isDebugBuild || isSimulator { return .debug }
        return isAppAttestSupported ? .appAttest : .deviceCheck
    }
}

/// Single entry point for Firebase startup, shared by the app and cold-launched
/// App Intents. App Check's provider factory must be installed before
/// `FirebaseApp.configure()`, so nothing else should call `configure()` directly.
enum FirebaseBootstrap {

    /// Idempotent: does nothing if Firebase is already configured in this process.
    static func configureIfNeeded() {
        #if canImport(FirebaseCore)
        guard FirebaseApp.app() == nil else { return }
        #if canImport(FirebaseAppCheck)
        AppCheck.setAppCheckProviderFactory(QuickSpendAppCheckProviderFactory())
        #endif
        FirebaseApp.configure()
        #endif
    }
}

#if canImport(FirebaseAppCheck)
private final class QuickSpendAppCheckProviderFactory: NSObject, AppCheckProviderFactory {

    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        let kind = AppCheckProviderKind.resolve(
            isDebugBuild: Self.isDebugBuild,
            isSimulator: Self.isSimulator,
            isAppAttestSupported: DCAppAttestService.shared.isSupported
        )
        print("[AppCheck] Using \(kind) provider")
        switch kind {
        case .debug: return AppCheckDebugProvider(app: app)
        case .appAttest: return AppAttestProvider(app: app)
        case .deviceCheck: return DeviceCheckProvider(app: app)
        }
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
#endif
