import SwiftUI
import SwiftData
import CoreData
import Combine
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct QuickSpendApp: App {
    @State private var appConfig = AppConfigViewModel()
    @State private var subscription = SubscriptionViewModel()
    @State private var cloudSync: CloudSyncService
    @State private var balance: BalanceService

    let modelContainer: ModelContainer

    /// Set to `true` ONLY when you need to push a new SwiftData schema to
    /// CloudKit's development environment (e.g. after adding/removing a model
    /// or changing a field). Build, run once on a DEBUG simulator/device, see
    /// "CloudKit development schema initialized" in the log, then set this back
    /// to `false` and commit.
    ///
    /// Why not gated by UserDefaults: a UserDefaults flag gets wiped on app
    /// uninstall, so reinstalling triggered the schema init again — and the
    /// container teardown after init crashes ("Illegal attempt to save to a
    /// file that was never opened") in iOS 18+. A source-controlled constant
    /// can't be wiped accidentally.
    private static let cloudKitSchemaInitEnabled = false

    init() {
        #if DEBUG
        if Self.cloudKitSchemaInitEnabled {
            let cloudConfig = ModelConfiguration(
                schema: AppSchema.schema,
                cloudKitDatabase: .private(AppSchema.cloudKitContainerId)
            )
            Self._initializeCloudKitSchema(config: cloudConfig)
        }
        #endif

        let resolvedContainer: ModelContainer
        do {
            resolvedContainer = try AppSchema.makeModelContainer()
            print("[QuickSpendApp] ModelContainer ready")
        } catch {
            fatalError("[QuickSpendApp] Failed to create ModelContainer: \(error)")
        }
        self.modelContainer = resolvedContainer
        try? WalletService.bootstrapIfNeeded(modelContext: resolvedContainer.mainContext)

        // CloudSyncService is shared with BalanceService via its didFinishImport
        // publisher — local insert via willSave AND remote import via Combine both
        // coalesce into the same 200ms debounce window inside BalanceService.
        let cloudSyncService = CloudSyncService()
        self._cloudSync = State(initialValue: cloudSyncService)
        self._balance = State(initialValue: BalanceService(
            modelContext: resolvedContainer.mainContext,
            importEventPublisher: cloudSyncService.didFinishImport.eraseToAnyPublisher()
        ))

        // Initialize SDKs after all stored properties are set
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
        AnalyticsService.initialize()
        GeminiParserService.initialize()
        subscription.initialize()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appConfig)
                .environment(subscription)
                .environment(cloudSync)
                .environment(balance)
                .preferredColorScheme(appConfig.colorScheme)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    appConfig.syncLanguageFromSystem()
                }
                .task {
                    appConfig.syncLanguageFromSystem()
                }
        }
        .modelContainer(modelContainer)
    }

    // MARK: - CloudKit Schema Initialization (DEBUG only)

    #if DEBUG
    /// Push the SwiftData schema to CloudKit's development environment.
    /// Runs inside autoreleasepool so the Core Data stack is fully deallocated
    /// before SwiftData's ModelContainer opens the same store.
    private static func _initializeCloudKitSchema(config: ModelConfiguration) {
        do {
            try autoreleasepool {
                let desc = NSPersistentStoreDescription(url: config.url)
                let opts = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: "iCloud.com.randomtech.quickSpend"
                )
                desc.cloudKitContainerOptions = opts
                desc.shouldAddStoreAsynchronously = false

                if let mom = NSManagedObjectModel.makeManagedObjectModel(for: AppSchema.models) {
                    let container = NSPersistentCloudKitContainer(name: "QuickSpend", managedObjectModel: mom)
                    container.persistentStoreDescriptions = [desc]
                    container.loadPersistentStores { _, error in
                        if let error {
                            print("[QuickSpendApp] CloudKit schema init store load error: \(error)")
                        }
                    }
                    try container.initializeCloudKitSchema()
                    if let store = container.persistentStoreCoordinator.persistentStores.first {
                        try container.persistentStoreCoordinator.remove(store)
                    }
                    print("[QuickSpendApp] CloudKit development schema initialized")
                }
            }
        } catch {
            print("[QuickSpendApp] CloudKit schema initialization failed: \(error)")
        }
    }
    #endif
}
