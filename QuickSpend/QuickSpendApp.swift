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

    /// Pass `-InitializeCloudKitSchema` as a DEBUG launch argument ONLY when you
    /// need to push a new SwiftData schema to CloudKit's development environment
    /// (e.g. after adding/removing a model or changing a field). The app initializes
    /// schema using a temporary store, then stops before opening the normal app store
    /// so a real device's local data is not accidentally synced into Development.
    ///
    /// Why not gated by UserDefaults: a UserDefaults flag can persist invisibly
    /// or be wiped during reinstall. A launch argument makes schema init explicit
    /// and one-run only.
    private static var cloudKitSchemaInitEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-InitializeCloudKitSchema")
    }

    init() {
        #if DEBUG
        if Self.cloudKitSchemaInitEnabled {
            Self._initializeCloudKitSchema()
            fatalError("[QuickSpendApp] CloudKit schema init finished. Remove -InitializeCloudKitSchema and run again.")
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
        do {
            _ = try WalletService.bootstrapIfNeeded(modelContext: resolvedContainer.mainContext)
        } catch {
            print("[WalletService] container-open repair failed: \(error)")
        }

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
    private static func _initializeCloudKitSchema() {
        do {
            try autoreleasepool {
                let storeURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("QuickSpendCloudKitSchemaInit.sqlite")
                let desc = NSPersistentStoreDescription(url: storeURL)
                let opts = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: AppSchema.cloudKitContainerId
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
