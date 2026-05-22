import Foundation
import SwiftData
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(RevenueCat)
import RevenueCat
#endif

/// Shared, lazily-initialized state for any App Intent that needs to touch
/// SwiftData, Firebase AI, or the subscription provider. Intents may run before
/// `QuickSpendApp.init` has executed, so we re-do the bits of startup they rely on.
@MainActor
enum IntentEnvironment {

    private static var cachedContainer: ModelContainer?
    private static var didInitGeminiSDK = false
    private static var didConfigureRevenueCat = false

    /// Returns the shared SwiftData container, building it once per process.
    static func container() throws -> ModelContainer {
        if let cached = cachedContainer { return cached }
        let container = try AppSchema.makeModelContainer()
        cachedContainer = container
        return container
    }

    /// Idempotently configures Firebase + Gemini so the parser can be used from
    /// a cold-launched intent.
    static func ensureParserReady() {
        guard !didInitGeminiSDK else { return }
        didInitGeminiSDK = true

        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
        GeminiParserService.initialize()
    }

    /// Snapshots the user's preferences for the current parse.
    static func currentConfig() -> AppConfig {
        PreferencesService.shared.getConfig()
    }

    /// Builds a `UsageLimitService` honouring the user's premium status. Premium
    /// is resolved from RevenueCat's cached entitlements when available so we
    /// don't penalise paying users invoking Siri before the app has run.
    static func makeUsageLimitService() async -> UsageLimitService {
        let service = UsageLimitService()
        service.isPremium = await resolvePremiumStatus()
        return service
    }

    static func resolvePremiumStatus() async -> Bool {
        #if canImport(RevenueCat)
        ensureRevenueCatConfigured()
        do {
            let info = try await Purchases.shared.customerInfo()
            return info.entitlements[SubscriptionViewModel.premiumEntitlementId]?.isActive == true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    private static func ensureRevenueCatConfigured() {
        #if canImport(RevenueCat)
        guard !didConfigureRevenueCat else { return }
        if !Purchases.isConfigured {
            Purchases.configure(withAPIKey: SubscriptionViewModel.appleApiKey)
        }
        didConfigureRevenueCat = true
        #endif
    }
}
