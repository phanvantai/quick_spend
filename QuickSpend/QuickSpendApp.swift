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

    init() {
        let schema = Schema([
            Transaction.self,
            Category.self,
            RecurringTemplate.self,
            BalanceAnchor.self,
        ])

        let cloudConfig = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.randomtech.quickSpend")
        )

        // Initialize CloudKit schema once during development, then skip on subsequent launches.
        #if DEBUG
        let schemaInitKey = "hasInitializedCloudKitSchema"
        if !UserDefaults.standard.bool(forKey: schemaInitKey) {
            Self._initializeCloudKitSchema(config: cloudConfig)
            UserDefaults.standard.set(true, forKey: schemaInitKey)
        }
        #endif

        let resolvedContainer: ModelContainer
        if let container = try? ModelContainer(for: schema, configurations: cloudConfig) {
            resolvedContainer = container
            print("[QuickSpendApp] ModelContainer created with CloudKit sync")
        } else {
            // Fallback to local-only storage if CloudKit is unavailable
            let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            do {
                resolvedContainer = try ModelContainer(for: schema, configurations: localConfig)
                print("[QuickSpendApp] ModelContainer created without CloudKit (fallback)")
            } catch {
                fatalError("[QuickSpendApp] Failed to create ModelContainer: \(error)")
            }
        }
        self.modelContainer = resolvedContainer

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

                if let mom = NSManagedObjectModel.makeManagedObjectModel(for: [
                    Transaction.self,
                    Category.self,
                    RecurringTemplate.self,
                    BalanceAnchor.self,
                ]) {
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
