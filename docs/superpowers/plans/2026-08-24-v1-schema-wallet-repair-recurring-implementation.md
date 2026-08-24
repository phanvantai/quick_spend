# V1 Schema, Wallet Repair, and Recurring Wallet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adopt the already-shipped App Store data model as SwiftData schema V1, make wallet repair safe and idempotent for existing CloudKit users, and allow recurring templates to select and edit their wallet.

**Architecture:** `QuickSpendSchemaV1` freezes the current top-level model types and `QuickSpendMigrationPlan` establishes the version chain without inventing V2. `WalletService.bootstrapIfNeeded` remains the post-open, post-import data-repair boundary and resolves invalid recurring wallet references through the active default-wallet policy. Recurring UI consumes the same active-wallet/default-wallet inputs as normal transaction entry.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, CloudKit-backed `ModelContainer`, Swift Testing, Xcode 16+, iOS 18+.

**Spec:** `docs/superpowers/specs/2026-08-24-v1-schema-wallet-repair-recurring-design.md`

## Global Constraints

- V1 is exactly the persisted model shape already shipped on the App Store.
- Do not create V2 without a structural persisted-model change.
- Never delete or replace the production store as migration recovery.
- Keep schema migration separate from idempotent post-open data repair.
- Preserve all existing transactions and their string `walletId` references.
- Changing a recurring template wallet affects only future generated transactions.
- Run repair after container open, after initial CloudKit import, and after later import events.
- Use TDD: observe RED before every production behavior change.
- Preserve unrelated user changes in the dirty worktree.

---

### Task 1: Freeze the App Store Model as Schema V1

**Files:**
- Create: `QuickSpend/Models/QuickSpendSchemaV1.swift`
- Modify: `QuickSpend/Models/AppSchema.swift:4-30`
- Modify: `QuickSpend/QuickSpendApp.swift:92-112`
- Test: `QuickSpendTests/AppSchemaMigrationTests.swift`

**Interfaces:**
- Produces: `QuickSpendSchemaV1.versionIdentifier`, `QuickSpendSchemaV1.models`, `QuickSpendMigrationPlan.schemas`, `QuickSpendMigrationPlan.stages`.
- Produces: `AppSchema.schema = Schema(versionedSchema: QuickSpendSchemaV1.self)` and `AppSchema.migrationPlan`.
- Consumes: the existing top-level `Transaction`, `Category`, `RecurringTemplate`, `BalanceAnchor`, and `Wallet` model types without changing them.

- [ ] **Step 1: Write a failing schema declaration test**

Add `QuickSpendTests/AppSchemaMigrationTests.swift`:

```swift
import Testing
import SwiftData
@testable import QuickSpend

@Suite("App Schema Migration Tests")
struct AppSchemaMigrationTests {
    @Test("App Store schema is frozen as V1")
    func appStoreSchemaIsV1() {
        #expect(QuickSpendSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(QuickSpendSchemaV1.models.count == 5)
        #expect(Set(AppSchema.schema.entities.map(\.name)) == [
            "Transaction", "Category", "RecurringTemplate", "BalanceAnchor", "Wallet"
        ])
        #expect(QuickSpendMigrationPlan.schemas.count == 1)
        #expect(QuickSpendMigrationPlan.stages.isEmpty)
    }
}
```

This test catches removal of the V1 declaration, wrong version, a missing shipped entity, or an invented migration stage.

- [ ] **Step 2: Run the schema test and verify RED**

Run:

```bash
xcodebuild -quiet -project QuickSpend.xcodeproj -scheme QuickSpend \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=8C3F601A-9E83-441C-A829-439FFCB54EFB' \
  -parallel-testing-enabled NO \
  -only-testing:QuickSpendTests/AppSchemaMigrationTests test
```

Expected: compile failure because `QuickSpendSchemaV1` and `QuickSpendMigrationPlan` do not exist.

- [ ] **Step 3: Add the minimal V1 and migration-plan declarations**

Create `QuickSpend/Models/QuickSpendSchemaV1.swift`:

```swift
import SwiftData

enum QuickSpendSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Transaction.self, Category.self, RecurringTemplate.self, BalanceAnchor.self, Wallet.self]
    }
}

enum QuickSpendMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [QuickSpendSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
```

Update `AppSchema`:

```swift
static let models = QuickSpendSchemaV1.models
static let schema = Schema(versionedSchema: QuickSpendSchemaV1.self)
static let migrationPlan: any SchemaMigrationPlan.Type = QuickSpendMigrationPlan.self
```

Pass `migrationPlan: QuickSpendMigrationPlan.self` to both CloudKit and local-only `ModelContainer` initializers. Keep `_initializeCloudKitSchema()` using `AppSchema.models`.

- [ ] **Step 4: Run the schema test and verify GREEN**

Run the command from Step 2. Expected: exit `0`, no warnings.

- [ ] **Step 5: Add the failing on-disk App Store compatibility test**

Extend `AppSchemaMigrationTests` with an `@MainActor` test that:

```swift
@Test("Versioned V1 opens an existing unversioned App Store store in place")
@MainActor
func versionedV1OpensExistingStore() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuickSpendV1Migration-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storeURL = directory.appendingPathComponent("QuickSpend.sqlite")

    func createLegacyStore() throws {
        let legacySchema = Schema(QuickSpendSchemaV1.models)
        let legacyContainer = try ModelContainer(
            for: legacySchema,
            configurations: ModelConfiguration(
                "LegacyAppStore",
                schema: legacySchema,
                url: storeURL,
                cloudKitDatabase: .none
            )
        )
        let legacyContext = legacyContainer.mainContext
        legacyContext.insert(Wallet.personal())
        legacyContext.insert(Transaction(
            id: "tx_preserved", amount: 125, note: "Preserve me",
            categoryId: "food", walletId: Wallet.personalID, type: .expense
        ))
        legacyContext.insert(RecurringTemplate(
            id: "recurring_preserved", amount: 500, note: "Rent",
            categoryId: "housing", walletId: Wallet.personalID, type: .expense
        ))
        legacyContext.insert(BalanceAnchor(
            walletId: Wallet.personalID, openingBalance: 2_000, anchorDate: .now
        ))
        legacyContext.insert(Category(
            id: "food", name: "Food", iconName: "fork.knife",
            colorHex: "#FF9500", type: .expense, group: .dailyLiving, sortOrder: 0
        ))
        try legacyContext.save()
    }
    try createLegacyStore()

    let migratedContainer = try ModelContainer(
        for: AppSchema.schema,
        migrationPlan: QuickSpendMigrationPlan.self,
        configurations: ModelConfiguration(
            "VersionedV1",
            schema: AppSchema.schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
    )
    let context = migratedContainer.mainContext
    #expect(try context.fetch(FetchDescriptor<Transaction>()).first?.id == "tx_preserved")
    #expect(try context.fetch(FetchDescriptor<RecurringTemplate>()).first?.walletId == Wallet.personalID)
    #expect(try context.fetchCount(FetchDescriptor<Category>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<BalanceAnchor>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<Wallet>()) == 1)
}
```

The production change that makes this fail is removing the migration plan or changing V1 so the shipped store can no longer open.

- [ ] **Step 6: Run the compatibility test and verify the real store opens**

Run the Task 1 test command. Expected: exit `0`; no deletion fallback is involved.

- [ ] **Step 7: Commit Task 1 only**

```bash
git add QuickSpend/Models/QuickSpendSchemaV1.swift \
  QuickSpend/Models/AppSchema.swift QuickSpend/QuickSpendApp.swift \
  QuickSpendTests/AppSchemaMigrationTests.swift
git commit -m "feat(schema): establish app store schema v1"
```

---

### Task 2: Repair Invalid Recurring Wallet References

**Files:**
- Modify: `QuickSpend/Services/WalletService.swift:45-119`
- Review and include the already-implemented wallet-scoped setter in `QuickSpend/Services/BalanceService.swift:228-268`
- Modify: `QuickSpend/QuickSpendApp.swift:39-57`
- Modify: `QuickSpend/Views/Splash/SplashView.swift:156-171`
- Modify: `QuickSpend/Services/BalanceService.swift:69-82`
- Test: `QuickSpendTests/WalletServiceTests.swift`
- Test: `QuickSpendTests/BalanceServiceTests.swift`

**Interfaces:**
- Consumes: `WalletService.activeWallets(from:)` and `WalletService.resolvedDefaultWalletId(wallets:preferences:)`.
- Produces: `WalletBootstrapResult` from an idempotent repair that fixes invalid recurring wallet references after wallet canonicalization.
- Preserves: valid transaction/template references and existing duplicate-wallet canonical-selection policy.

- [ ] **Step 1: Write failing recurring migration tests**

Add three tests to `WalletServiceTests`:

```swift
@Test("bootstrap assigns an empty recurring wallet to the active configured default")
func bootstrapAssignsEmptyRecurringWalletToDefault() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let preferences = makePreferences()
    let personal = Wallet.personal()
    let sideWork = Wallet(id: "wallet_side_work", name: "Side Work",
                          iconName: "briefcase.fill", colorHex: "#2563EB")
    let template = RecurringTemplate(amount: 500, note: "Tools", categoryId: "tools")
    template.walletId = ""
    context.insert(personal); context.insert(sideWork); context.insert(template)
    preferences.setDefaultWalletId(sideWork.id)
    try context.save()

    _ = try WalletService.bootstrapIfNeeded(modelContext: context, preferences: preferences)

    #expect(template.walletId == sideWork.id)
}

@Test("bootstrap repairs missing and archived recurring wallets")
func bootstrapRepairsInvalidRecurringWallets() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let preferences = makePreferences()
    let personal = Wallet.personal()
    let archived = Wallet(
        id: "wallet_archived", name: "Archived", iconName: "archivebox.fill",
        colorHex: "#8E8E93", isArchived: true
    )
    let archivedTemplate = RecurringTemplate(
        amount: 100, note: "Archived wallet", categoryId: "other_expense",
        walletId: "wallet_archived"
    )
    let missingTemplate = RecurringTemplate(
        amount: 200, note: "Missing wallet", categoryId: "other_expense",
        walletId: "wallet_missing"
    )
    context.insert(personal); context.insert(archived)
    context.insert(archivedTemplate); context.insert(missingTemplate)
    preferences.setDefaultWalletId(archived.id)
    try context.save()

    _ = try WalletService.bootstrapIfNeeded(modelContext: context, preferences: preferences)

    #expect(archivedTemplate.walletId == Wallet.personalID)
    #expect(missingTemplate.walletId == Wallet.personalID)
}

@Test("bootstrap keeps a valid recurring wallet and is idempotent")
func bootstrapKeepsValidRecurringWallet() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let preferences = makePreferences()
    let personal = Wallet.personal()
    let sideWork = Wallet(
        id: "wallet_side_work", name: "Side Work",
        iconName: "briefcase.fill", colorHex: "#2563EB"
    )
    let template = RecurringTemplate(
        amount: 500, note: "Tools", categoryId: "tools",
        walletId: "wallet_side_work"
    )
    context.insert(personal); context.insert(sideWork); context.insert(template)
    try context.save()

    _ = try WalletService.bootstrapIfNeeded(modelContext: context, preferences: preferences)
    let second = try WalletService.bootstrapIfNeeded(modelContext: context, preferences: preferences)

    #expect(template.walletId == "wallet_side_work")
    #expect(second.didCreatePersonalWallet == false)
    #expect(second.didMigrateLegacyData == false)
}
```

Use literal wallet IDs in every expectation; do not derive expected values through the resolver under test.

- [ ] **Step 2: Run WalletServiceTests and verify RED**

Run:

```bash
xcodebuild -quiet -project QuickSpend.xcodeproj -scheme QuickSpend \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=8C3F601A-9E83-441C-A829-439FFCB54EFB' \
  -parallel-testing-enabled NO \
  -only-testing:QuickSpendTests/WalletServiceTests test
```

Expected: empty-wallet test reports Personal instead of `wallet_side_work`; missing/archived references remain invalid.

- [ ] **Step 3: Implement minimal recurring data repair**

After duplicate-wallet deletion and Personal creation, derive active canonical business IDs and the resolved default:

```swift
let survivingWallets = wallets.filter { wallet in
    !modelContext.deletedModelsArray.contains { deleted in
        guard let deletedWallet = deleted as? Wallet else { return false }
        return deletedWallet === wallet
    }
}
let activeWallets = activeWallets(from: survivingWallets)
let resolvedDefaultWalletId = resolvedDefaultWalletId(
    wallets: activeWallets,
    preferences: preferences
)
let activeWalletIds = Set(activeWallets.map(\.id))

for template in templates
where template.walletId.isEmpty || !activeWalletIds.contains(template.walletId) {
    template.walletId = resolvedDefaultWalletId
    didMigrateLegacyData = true
}
```

Prefer constructing an explicit canonical wallet array while grouping rather than querying SwiftData deletion internals if that keeps `WalletService` clearer. Personal must be included in the effective active set even when it was inserted in this repair.

Keep transaction empty-ID repair targeting Personal to preserve the established legacy contract. Do not rewrite a non-empty transaction reference.

- [ ] **Step 4: Make repair failures observable at all trigger points**

Replace silent `try?` calls with scoped `do/catch` blocks:

```swift
do {
    _ = try WalletService.bootstrapIfNeeded(modelContext: context)
} catch {
    print("[WalletService] <phase> repair failed: \(error)")
}
```

Use phase labels `container-open`, `initial-cloud-import`, and `cloud-import-event` in `QuickSpendApp`, `SplashView`, and `BalanceService`. Do not change launch continuation behavior.

- [ ] **Step 5: Run WalletServiceTests and verify GREEN**

Run the command from Step 2. Expected: exit `0`.

- [ ] **Step 6: Run CloudSync and Splash focused tests**

```bash
xcodebuild -quiet -project QuickSpend.xcodeproj -scheme QuickSpend \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=8C3F601A-9E83-441C-A829-439FFCB54EFB' \
  -parallel-testing-enabled NO \
  -only-testing:QuickSpendTests/CloudSyncTests \
  -only-testing:QuickSpendTests/SplashViewLaunchLogicTests test
```

Expected: exit `0`.

- [ ] **Step 7: Commit Task 2 only**

```bash
git add QuickSpend/Services/WalletService.swift QuickSpend/QuickSpendApp.swift \
  QuickSpend/Views/Splash/SplashView.swift QuickSpend/Services/BalanceService.swift \
  QuickSpendTests/WalletServiceTests.swift QuickSpendTests/BalanceServiceTests.swift
git commit -m "fix(wallets): repair recurring wallet ownership"
```

---

### Task 3: Add Wallet Selection to Recurring Create and Edit

**Files:**
- Modify: `QuickSpend/Views/Recurring/RecurringFormView.swift:4-216`
- Modify: `QuickSpend/Views/Recurring/RecurringListView.swift:5-88`
- Modify: `QuickSpend/Views/Recurring/RecurringListView.swift:119-173`
- Modify: recurring previews to include `Wallet.self`
- Test: `QuickSpendTests/RecurringTemplateTests.swift`
- Test: `QuickSpendTests/RecurringServiceTests.swift`

**Interfaces:**
- Produces: `RecurringFormView.resolveInitialWalletId(existingTemplate:wallets:defaultWalletId:) -> String`.
- Consumes: `[Wallet]`, resolved default wallet ID, and optional `RecurringTemplate`.
- Preserves: `RecurringService` copying `template.walletId` to future generated transactions.

- [ ] **Step 1: Write failing wallet-selection tests**

Add `@MainActor` tests to `RecurringTemplateTests`:

```swift
@Test("New recurring form starts with the resolved default wallet")
@MainActor
func recurringFormUsesDefaultWallet() {
    let wallets = [Wallet.personal(), Wallet(
        id: "wallet_side_work", name: "Side Work",
        iconName: "briefcase.fill", colorHex: "#2563EB"
    )]
    #expect(RecurringFormView.resolveInitialWalletId(
        existingTemplate: nil,
        wallets: wallets,
        defaultWalletId: "wallet_side_work"
    ) == "wallet_side_work")
}

@Test("Editing recurring form keeps an active assigned wallet")
@MainActor
func recurringFormKeepsExistingWallet() {
    let personal = Wallet.personal()
    let sideWork = Wallet(
        id: "wallet_side_work", name: "Side Work",
        iconName: "briefcase.fill", colorHex: "#2563EB"
    )
    let template = RecurringTemplate(
        amount: 100, note: "Tools", categoryId: "tools",
        walletId: "wallet_side_work"
    )
    #expect(RecurringFormView.resolveInitialWalletId(
        existingTemplate: template,
        wallets: [personal, sideWork],
        defaultWalletId: Wallet.personalID
    ) == "wallet_side_work")

    sideWork.isArchived = true
    #expect(RecurringFormView.resolveInitialWalletId(
        existingTemplate: template,
        wallets: [personal, sideWork],
        defaultWalletId: Wallet.personalID
    ) == Wallet.personalID)
}
```

The mutation these tests catch is defaulting every edit to Personal or ignoring the existing template wallet.

- [ ] **Step 2: Run RecurringTemplateTests and verify RED**

Run:

```bash
xcodebuild -quiet -project QuickSpend.xcodeproj -scheme QuickSpend \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=8C3F601A-9E83-441C-A829-439FFCB54EFB' \
  -parallel-testing-enabled NO \
  -only-testing:QuickSpendTests/RecurringTemplateTests test
```

Expected: compile failure because `resolveInitialWalletId` does not exist.

- [ ] **Step 3: Add recurring form wallet inputs and picker**

Update `RecurringFormView` initializer:

```swift
let wallets: [Wallet]
let defaultWalletId: String
@State private var selectedWalletId: String

init(
    categories: [Category],
    wallets: [Wallet] = [],
    defaultWalletId: String = Wallet.personalID,
    existingTemplate: RecurringTemplate? = nil,
    onSave: @escaping (RecurringTemplate) -> Void
) {
    let activeWallets = WalletService.activeWallets(from: wallets)
    _selectedWalletId = State(initialValue: Self.resolveInitialWalletId(
        existingTemplate: existingTemplate,
        wallets: activeWallets,
        defaultWalletId: defaultWalletId
    ))
    _noteText = State(initialValue: existingTemplate?.note ?? "")
    _amountText = State(initialValue: existingTemplate.map { String(format: "%.2f", $0.amount) } ?? "")
    _selectedCategoryId = State(initialValue: existingTemplate?.categoryId ?? "other_expense")
    _selectedType = State(initialValue: existingTemplate?.type ?? .expense)
    _selectedPattern = State(initialValue: existingTemplate?.pattern ?? .monthly)
    _startDate = State(initialValue: existingTemplate?.startDate ?? .now)
    _hasEndDate = State(initialValue: existingTemplate?.endDate != nil)
    _endDate = State(initialValue: existingTemplate?.endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: .now)!)
}
```

The resolver returns the existing template wallet when active, otherwise the supplied active default when present, otherwise Personal.

Add a menu `Picker` section using `wallets` and `wallet.displayName(language:)`. Render it only when more than one active wallet exists. Pass `walletId: selectedWalletId` to the saved `RecurringTemplate`.

- [ ] **Step 4: Wire list create and edit callbacks**

Add `@Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]` to `RecurringListView`. Resolve:

```swift
private var activeWallets: [Wallet] { WalletService.activeWallets(from: wallets) }
private var defaultWalletId: String {
    WalletService.resolvedDefaultWalletId(wallets: activeWallets)
}
```

Pass both inputs to add and edit sheets. In the edit callback add:

```swift
template.walletId = updated.walletId
```

Update the preview model container to include `Wallet.self`.

- [ ] **Step 5: Run RecurringTemplateTests and verify GREEN**

Run the command from Step 2. Expected: exit `0`.

- [ ] **Step 6: Add and run the future-generation regression**

Extend `RecurringServiceTests` with a template assigned to Personal, edit `template.walletId` to `wallet_side_work`, generate one due transaction, and assert the generated transaction uses literal `wallet_side_work`. This protects the user contract that edits affect future transactions only.

Run:

```bash
xcodebuild -quiet -project QuickSpend.xcodeproj -scheme QuickSpend \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=8C3F601A-9E83-441C-A829-439FFCB54EFB' \
  -parallel-testing-enabled NO \
  -only-testing:QuickSpendTests/RecurringServiceTests test
```

Expected: exit `0`.

- [ ] **Step 7: Commit Task 3 only**

```bash
git add QuickSpend/Views/Recurring/RecurringFormView.swift \
  QuickSpend/Views/Recurring/RecurringListView.swift \
  QuickSpendTests/RecurringTemplateTests.swift QuickSpendTests/RecurringServiceTests.swift
git commit -m "feat(recurring): allow wallet selection"
```

---

### Task 4: Verify Existing Duplicate-Wallet and Balance UX Work

**Files:**
- Review existing dirty changes in `QuickSpend/Services/BalanceService.swift`
- Review existing dirty changes in `QuickSpend/Services/WalletService.swift`
- Review existing dirty changes under `QuickSpend/Views/Home`, `QuickSpend/Views/Settings`, and `QuickSpend/Views/Wallets`
- Review existing tests in `QuickSpendTests/BalanceServiceTests.swift`, `QuickSpendTests/CurrencyFormatterTests.swift`, and `QuickSpendTests/WalletServiceTests.swift`

**Interfaces:**
- Consumes: the previously implemented duplicate repair and wallet-scoped balance setter.
- Produces: the approved Home → wallet management → wallet edit balance flow, with no standalone balance editor.

- [ ] **Step 1: Re-read the dirty diff against the spec**

Verify all of these from code, not source-text tests:

- Home balance tap presents `WalletManagementView`.
- Settings contains no balance editor route.
- Editing a wallet exposes balance; creating one does not.
- Unchanged formatted balance does not move the anchor.
- Duplicate wallet deletion preserves transaction business references.

- [ ] **Step 2: Run the focused regression suites**

```bash
xcodebuild -quiet -project QuickSpend.xcodeproj -scheme QuickSpend \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=8C3F601A-9E83-441C-A829-439FFCB54EFB' \
  -parallel-testing-enabled NO \
  -only-testing:QuickSpendTests/WalletServiceTests \
  -only-testing:QuickSpendTests/BalanceServiceTests \
  -only-testing:QuickSpendTests/CurrencyFormatterTests test
```

Expected: exit `0`, no warnings.

- [ ] **Step 3: Commit the remaining approved wallet/balance UI changes**

Stage the reviewed UI files, deleted standalone editors, and their formatting regression, then commit:

```bash
git add QuickSpend/Views/Home/BalanceEditSheet.swift \
  QuickSpend/Views/Home/Components/BalanceHero.swift \
  QuickSpend/Views/Home/HomeView.swift QuickSpend/Views/Home/WhatsNewBalanceModal.swift \
  QuickSpend/Views/Settings/BalanceWalletPickerView.swift \
  QuickSpend/Views/Settings/Sections/CoreSection.swift \
  QuickSpend/Views/Settings/SettingsView.swift \
  QuickSpend/Views/Wallets/WalletFormView.swift \
  QuickSpend/Views/Wallets/WalletManagementView.swift \
  QuickSpendTests/CurrencyFormatterTests.swift
git commit -m "fix(wallets): repair duplicates and consolidate balance editing"
```

Do not stage unrelated files.

---

### Task 5: Full Verification and Independent Review

**Files:**
- No production changes expected unless verification exposes a defect.

**Interfaces:**
- Verifies all prior task outputs together.

- [ ] **Step 1: Run all unit tests**

```bash
xcodebuild -quiet -project QuickSpend.xcodeproj -scheme QuickSpend \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=8C3F601A-9E83-441C-A829-439FFCB54EFB' \
  -parallel-testing-enabled NO \
  -only-testing:QuickSpendTests test
```

Expected: exit `0`, zero failing tests.

- [ ] **Step 2: Run a clean simulator build**

```bash
xcodebuild -quiet -project QuickSpend.xcodeproj -scheme QuickSpend \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=8C3F601A-9E83-441C-A829-439FFCB54EFB' build
```

Expected: exit `0`, no warnings.

- [ ] **Step 3: Check repository integrity**

```bash
git diff --check
git status --short
git log --oneline --decorate -8
```

Expected: no whitespace errors; only intentional files remain uncommitted.

- [ ] **Step 4: Request independent code review**

Review against the spec with explicit attention to:

- unversioned App Store store compatibility;
- frozen V1 entity identity;
- duplicate cleanup and CloudKit timing;
- invalid recurring-wallet fallback;
- create/edit recurring wallet selection;
- transaction and historical generated-transaction preservation.

- [ ] **Step 5: Address findings with another RED/GREEN cycle**

For every accepted behavior defect, add or strengthen a regression test, observe failure, implement the minimal correction, and rerun the affected focused suite before repeating full verification.

- [ ] **Step 6: Report release-only checks separately**

Do not claim these offline checks were performed locally:

- CloudKit Development schema inspection;
- Production schema field confirmation;
- two-device deletion propagation;
- upgrade-over-App-Store-install smoke test.

List them as required manual release validation unless the user explicitly authorizes and provides access for those environments.
