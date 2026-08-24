# Balance Adjustment V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship schema V2 with an immutable balance-adjustment ledger so manual reconciliation and transaction create/edit/delete keep every affected wallet balance correct across anchors and CloudKit.

**Architecture:** V2 adds only `BalanceAdjustment`; the five V1 entity definitions stay byte-for-byte compatible. `BalanceService` computes anchors plus post-anchor transactions plus all adjustments. A new explicit transaction persistence boundary calculates wallet targets from pre-mutation balances, inserts only the compensating adjustments needed after the mutation, saves atomically, restores on failure, and publishes balances after persistence.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Observation, Swift Testing, CloudKit-backed `ModelContainer`, iOS 18 simulator.

**Spec:** `docs/superpowers/specs/2026-08-24-balance-adjustment-v2-design.md`

## Global Constraints

- Preserve the exact frozen V1 five-entity signature and never delete/replace a store after migration failure.
- Runtime schema is V2; support both versioned V1-to-V2 and shipped unversioned-shape-to-V2 upgrades.
- Adjustments are immutable, signed, included without an anchor-date predicate, and never created for a wallet without an anchor.
- Manual reconciliation leaves an existing anchor's `openingBalance` and `anchorDate` unchanged.
- Transaction mutation targets derive from authoritative balances immediately before mutation, not timestamp comparison.
- Transaction mutation plus adjustments persist in one explicit save; UI dismisses only after success.
- Pure wallet moves preserve combined balance; historical transactions already persisted before V2 are never guessed or rewritten.
- CloudKit-compatible models use defaults and no unique attributes.
- Follow TDD for every behavior change and keep tests isolated/offline.

---

### Task 1: Add Schema V2 and Prove Both Upgrade Paths

**Files:**
- Create: `QuickSpend/Models/BalanceAdjustment.swift`
- Create: `QuickSpend/Models/QuickSpendSchemaV2.swift`
- Modify: `QuickSpend/Models/QuickSpendSchemaV1.swift`
- Modify: `QuickSpend/Models/AppSchema.swift`
- Modify: model-container previews/tests that exercise the runtime V2 schema
- Test: `QuickSpendTests/AppSchemaMigrationTests.swift`

**Interfaces:**
- Produces: `BalanceAdjustment`, `BalanceAdjustmentReason`, `QuickSpendSchemaV2`, and `QuickSpendMigrationPlan.v1ToV2`.
- Preserves: `QuickSpendSchemaV1.models` and its checked-in 47-attribute signature.

- [ ] **Step 1: Write failing V2 signature and migration tests**

Add tests that expect `QuickSpendSchemaV2.versionIdentifier == Schema.Version(2, 0, 0)`, exactly six entities, and these adjustment attributes:

```swift
let expectedAdjustmentSignature: Set<String> = [
    "BalanceAdjustment|amount|Double|attribute|required|nonunique|persisted|Double(0.0)",
    "BalanceAdjustment|createdAt|Date|attribute|required|nonunique|persisted|Date.dynamic",
    "BalanceAdjustment|id|String|attribute|required|nonunique|persisted|String()",
    "BalanceAdjustment|operationId|String|attribute|required|nonunique|persisted|String()",
    "BalanceAdjustment|reason|String|attribute|required|nonunique|persisted|String(manual_reconciliation)",
    "BalanceAdjustment|sourceTransactionId|String|attribute|optional|nonunique|persisted|nil",
    "BalanceAdjustment|walletId|String|attribute|required|nonunique|persisted|String(wallet_personal)",
]
```

Extend the on-disk compatibility fixture twice: open a versioned V1 store as V2, and open a five-model unversioned shipped-shape store directly with the final V2 migration plan. Assert all original rows and references survive and an inserted adjustment persists after reopen.

Change the V1 signature helper to inspect `Schema(versionedSchema: QuickSpendSchemaV1.self)` rather than `AppSchema.schema`; runtime `AppSchema.schema` is V2 and must not contaminate the frozen V1 assertion. Split the current runtime assertion into one test for frozen V1 and one test for V2 runtime/migration-plan composition.

- [ ] **Step 2: Run migration tests and verify RED**

Run:

```bash
xcodebuild -quiet -project QuickSpend.xcodeproj -scheme QuickSpend \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=8C3F601A-9E83-441C-A829-439FFCB54EFB' \
  -parallel-testing-enabled NO \
  -only-testing:QuickSpendTests/AppSchemaMigrationTests test
```

Expected: compile failure because V2 and `BalanceAdjustment` do not exist.

- [ ] **Step 3: Implement the additive model and migration**

Create:

```swift
enum BalanceAdjustmentReason: String, Codable, CaseIterable {
    case manualReconciliation = "manual_reconciliation"
    case transactionEdit = "transaction_edit"
    case transactionDelete = "transaction_delete"
}

@Model
final class BalanceAdjustment {
    var id: String = ""
    var operationId: String = ""
    var walletId: String = Wallet.personalID
    var amount: Double = 0
    var reason: String = BalanceAdjustmentReason.manualReconciliation.rawValue
    var sourceTransactionId: String?
    var createdAt: Date = .now

    init(id: String = UUID().uuidString, operationId: String = UUID().uuidString,
         walletId: String, amount: Double, reason: BalanceAdjustmentReason,
         sourceTransactionId: String? = nil, createdAt: Date = .now) {
        self.id = id
        self.operationId = operationId
        self.walletId = walletId
        self.amount = amount
        self.reason = reason.rawValue
        self.sourceTransactionId = sourceTransactionId
        self.createdAt = createdAt
    }
}
```

Define `QuickSpendSchemaV2.models` as the unchanged V1 five models plus `BalanceAdjustment.self`. Add `MigrationStage.lightweight(fromVersion: QuickSpendSchemaV1.self, toVersion: QuickSpendSchemaV2.self)`, and point `AppSchema.models/schema` at V2.

Update in-memory containers that instantiate `BalanceService`, `WalletService`, or runtime previews to include `BalanceAdjustment.self`; keep legacy migration fixtures at exactly five models.

- [ ] **Step 4: Run migration tests and verify GREEN**

Run the Step 2 command. Expected: exit `0` with no warnings.

- [ ] **Step 5: Commit Task 1**

```bash
git add QuickSpend/Models QuickSpend/Views QuickSpendTests/AppSchemaMigrationTests.swift
git commit -m "feat(schema): add balance adjustment v2"
```

Stage only model-container preview/test files actually changed.

---

### Task 2: Compute Adjustments and Preserve Manual Reconciliation

**Files:**
- Modify: `QuickSpend/Services/BalanceService.swift`
- Test: `QuickSpendTests/BalanceServiceTests.swift`
- Test: `QuickSpendTests/CurrencyFormatterTests.swift`

**Interfaces:**
- Consumes: `BalanceAdjustment` and `BalanceAdjustmentReason.manualReconciliation`.
- Produces: authoritative adjustment-aware `computeBalance(walletId:)`, adjustment-based `setCurrentBalance`, and internal balance target publication helpers for Task 3.

- [ ] **Step 1: Write failing adjustment-computation tests**

Add literal tests for:

```swift
// Anchor 1_000 + post-anchor expense 100 + adjustments (+25, -5) = 920.
#expect(try service.computeBalance(walletId: "wallet_a") == 920)

// Adjustment timestamp predates anchor but remains included.
#expect(try service.computeBalance(walletId: "wallet_a") == 925)
```

Also test a wallet without an anchor remains `nil` despite an adjustment row.

- [ ] **Step 2: Write failing manual-reconciliation tests**

Create an anchor with fixed `openingBalance` and `anchorDate`, call `setCurrentBalance`, then assert:

```swift
#expect(anchor.openingBalance == 1_000)
#expect(anchor.anchorDate == originalAnchorDate)
#expect(adjustments.count == 1)
#expect(adjustments[0].amount == 250)
#expect(adjustments[0].reason == "manual_reconciliation")
#expect(try service.computeBalance(walletId: "wallet_a") == 1_250)
```

Call it again with the already-displayed value and assert no second adjustment. Keep the existing first-setup test proving a missing anchor is created.

- [ ] **Step 3: Run focused tests and verify RED**

Run:

```bash
xcodebuild -quiet -project QuickSpend.xcodeproj -scheme QuickSpend \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=8C3F601A-9E83-441C-A829-439FFCB54EFB' \
  -parallel-testing-enabled NO \
  -only-testing:QuickSpendTests/BalanceServiceTests \
  -only-testing:QuickSpendTests/CurrencyFormatterTests test
```

Expected: adjustment sums are missing and existing anchors move.

- [ ] **Step 4: Implement adjustment-aware balance behavior**

Add a wallet-filtered adjustment fetch and include its signed sum in `computeBalance(walletId:)` without filtering by `createdAt`.

Change `setCurrentBalance`:

```swift
if let existing = try fetchAnchor(walletId: walletId) {
    let current = try computeBalance(walletId: walletId) ?? existing.openingBalance
    let delta = amount - current
    if abs(delta) > 0.000_001 {
        let operationId = UUID().uuidString
        modelContext.insert(BalanceAdjustment(
            id: "\(operationId):\(walletId)", operationId: operationId,
            walletId: walletId, amount: delta, reason: .manualReconciliation
        ))
    }
} else {
    modelContext.insert(BalanceAnchor(walletId: walletId, openingBalance: amount, anchorDate: date))
}
```

Save once, publish the confirmed amount, and schedule reconciliation only if the post-save authoritative refresh fails.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run the Step 3 command. Expected: exit `0`, no warnings.

- [ ] **Step 6: Commit Task 2**

```bash
git add QuickSpend/Services/BalanceService.swift QuickSpendTests/BalanceServiceTests.swift QuickSpendTests/CurrencyFormatterTests.swift
git commit -m "feat(balance): record reconciliation adjustments"
```

---

### Task 3: Persist Transaction Mutations and Compensating Adjustments

**Files:**
- Create: `QuickSpend/Services/TransactionPersistence.swift`
- Modify: `QuickSpend/Services/BalanceService.swift`
- Test: `QuickSpendTests/TransactionPersistenceTests.swift`

**Interfaces:**
- Produces: `TransactionPersistence.create`, `update`, `delete`, and `createMany`, all `@MainActor` throwing operations.
- Consumes: authoritative pre/post balances and post-save publication from `BalanceService`.

- [ ] **Step 1: Write failing target-calculation and durability tests**

Use real in-memory SwiftData for target math and real temporary SQLite stores for durability. Cover literal outcomes:

```text
old expense before both anchors: source 1_000 -> 1_100; destination 500 -> 400
old expense after both anchors:  source 900 -> 1_000; destination 500 -> 400
same-wallet expense 100 -> 250: balance 900 -> 750
move expense 100 -> income 200: source +100; destination +200
pure move: combined balance unchanged
```

Assert compensating adjustment rows exist only where the natural post-mutation computation misses the target. Add note/category/date-only edit coverage expecting zero adjustments.

Close and reopen an on-disk store after update and delete, asserting transaction state, adjustment rows, and computed wallet balances persist.

- [ ] **Step 2: Run persistence tests and verify RED**

Run:

```bash
xcodebuild -quiet -project QuickSpend.xcodeproj -scheme QuickSpend \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=8C3F601A-9E83-441C-A829-439FFCB54EFB' \
  -parallel-testing-enabled NO \
  -only-testing:QuickSpendTests/TransactionPersistenceTests test
```

Expected: compile failure because `TransactionPersistence` does not exist.

- [ ] **Step 3: Implement the explicit persistence boundary**

Define snapshot and contribution value types inside `TransactionPersistence`. Implement target math from literal signed contributions. Each mutation performs:

```swift
let before = try balanceService.authoritativeBalances(for: affectedWalletIds)
let targets = targets(before: before, old: oldContribution, new: newContribution)
applyMutation()
let naturalAfter = try balanceService.authoritativeBalances(for: affectedWalletIds)
let deltas = Dictionary(uniqueKeysWithValues: targets.compactMap { walletId, target in
    guard let natural = naturalAfter[walletId] else { return nil }
    return (walletId, target - natural)
})
insertNonZeroAdjustments(deltas, operationId: operationId)
try modelContext.save()
balanceService.publish(targets)
```

Use one operation ID and deterministic `<operationId>:<walletId>` row IDs. On failure, delete newly inserted adjustments, restore every transaction field or undo the pending deletion, restore published balances, and rethrow without rolling back unrelated context state.

`createMany` saves all inserted transactions once and publishes each affected wallet after the save.

- [ ] **Step 4: Add save-failure tests**

Add an internal defaulted save dependency to each persistence entry point:

```swift
typealias SaveContext = @MainActor (ModelContext) throws -> Void
static let defaultSave: SaveContext = { try $0.save() }
```

Tests pass `{ _ in throw PersistenceFailure.injected }`; production omits the argument. Prove failed create/edit/delete leaves no adjustment, restores transaction visibility and fields, and leaves published balances at their pre-mutation literals.

- [ ] **Step 5: Run persistence tests and verify GREEN**

Run the Step 2 command. Expected: exit `0`, no warnings.

- [ ] **Step 6: Commit Task 3**

```bash
git add QuickSpend/Services/TransactionPersistence.swift QuickSpend/Services/BalanceService.swift QuickSpendTests/TransactionPersistenceTests.swift
git commit -m "fix(transactions): reconcile wallet balances atomically"
```

---

### Task 4: Wire Throwing UI Saves and Adjustment Repair

**Files:**
- Modify: `QuickSpend/Views/TransactionForm/TransactionFormView.swift`
- Modify: `QuickSpend/Views/Transactions/TransactionsView.swift`
- Modify: `QuickSpend/Views/Home/HomeView.swift`
- Modify: `QuickSpend/Views/Main/VoiceFABLayer.swift`
- Modify: `QuickSpend/Views/Voice/EditableExpenseDialog.swift`
- Modify: `QuickSpend/Services/WalletService.swift`
- Modify: `QuickSpend/Localizable.xcstrings`
- Test: `QuickSpendTests/WalletServiceTests.swift`
- Test: `QuickSpendTests/TransactionPersistenceTests.swift`
- Test: `QuickSpendTests/L10nTests.swift`

**Interfaces:**
- Consumes: all `TransactionPersistence` operations.
- Produces: save-error-retaining transaction forms and idempotent adjustment duplicate repair at existing container/CloudKit triggers.

- [ ] **Step 1: Add failing adjustment duplicate-repair test**

Insert two adjustment rows with the same literal ID and one separate operation. Run `WalletService.bootstrapIfNeeded`, then assert one duplicate survives, the distinct row remains, and a second repair changes nothing.

- [ ] **Step 2: Implement adjustment duplicate repair**

Fetch `BalanceAdjustment`, group by `id`, retain a deterministic row using `createdAt` then persisted field ordering, and delete extras in the same bootstrap save. Extend `WalletBootstrapResult` only if tests need to report the repair; do not merge different IDs.

- [ ] **Step 3: Make form callbacks throwing**

Change `TransactionFormView.onSave` and `EditableExpenseDialog.onSave` to throwing closures. Wrap saves in `do/catch`; dismiss only on success and show a localized save error while retaining entered state on failure.

- [ ] **Step 4: Replace mutation call sites**

Wire:

- Home and Transactions add -> `try TransactionPersistence.create`;
- Transactions edit -> `try TransactionPersistence.update`;
- Transactions delete -> `try TransactionPersistence.delete`, showing an alert on failure;
- Voice/manual batch -> `try TransactionPersistence.createMany`.

Remove direct `modelContext.insert/delete`, manual field-copy edit code, and `applyOptimisticInsert/Delete/Edit` calls from those UI paths once no production callers remain.

- [ ] **Step 5: Run focused UI/service tests**

Run:

```bash
xcodebuild -quiet -project QuickSpend.xcodeproj -scheme QuickSpend \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=8C3F601A-9E83-441C-A829-439FFCB54EFB' \
  -parallel-testing-enabled NO \
  -only-testing:QuickSpendTests/TransactionPersistenceTests \
  -only-testing:QuickSpendTests/WalletServiceTests \
  -only-testing:QuickSpendTests/BalanceServiceTests test
```

Expected: exit `0`, no warnings.

- [ ] **Step 6: Commit Task 4**

```bash
git add QuickSpend/Views/TransactionForm/TransactionFormView.swift \
  QuickSpend/Views/Transactions/TransactionsView.swift \
  QuickSpend/Views/Home/HomeView.swift QuickSpend/Views/Main/VoiceFABLayer.swift \
  QuickSpend/Views/Voice/EditableExpenseDialog.swift \
  QuickSpend/Services/WalletService.swift QuickSpend/Localizable.xcstrings \
  QuickSpendTests/WalletServiceTests.swift QuickSpendTests/TransactionPersistenceTests.swift \
  QuickSpendTests/L10nTests.swift
git commit -m "fix(transactions): persist balance reconciliation flows"
```

Stage only files changed by this task.

---

### Task 5: Full Verification and Release Handoff

**Files:**
- No production changes expected unless verification exposes a tested defect.

**Interfaces:**
- Verifies the complete V2 system and App Store upgrade contract.

- [ ] **Step 1: Run focused schema and financial correctness suites**

```bash
xcodebuild -quiet -project QuickSpend.xcodeproj -scheme QuickSpend \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=8C3F601A-9E83-441C-A829-439FFCB54EFB' \
  -parallel-testing-enabled NO \
  -only-testing:QuickSpendTests/AppSchemaMigrationTests \
  -only-testing:QuickSpendTests/BalanceServiceTests \
  -only-testing:QuickSpendTests/TransactionPersistenceTests \
  -only-testing:QuickSpendTests/WalletServiceTests test
```

Expected: exit `0`, zero failures/warnings.

- [ ] **Step 2: Run all unit tests**

```bash
xcodebuild -quiet -project QuickSpend.xcodeproj -scheme QuickSpend \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=8C3F601A-9E83-441C-A829-439FFCB54EFB' \
  -parallel-testing-enabled NO \
  -only-testing:QuickSpendTests test
```

Expected: exit `0`.

- [ ] **Step 3: Run a clean simulator build and integrity checks**

```bash
xcodebuild -quiet -project QuickSpend.xcodeproj -scheme QuickSpend \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=8C3F601A-9E83-441C-A829-439FFCB54EFB' build
git diff --check
git status --short
```

Expected: build exit `0`, no warnings, clean worktree.

- [ ] **Step 4: Independent review**

Review the branch from `origin/main` to HEAD against the V2 spec, focusing on unversioned App Store upgrade, adjustment double-counting, transaction rollback, CloudKit duplicate delivery, and pure-move combined-total preservation. Fix every accepted behavior finding with a RED/GREEN cycle and repeat verification.

- [ ] **Step 5: Report release-only checks**

Do not claim these were performed locally: V2 CloudKit Development initialization, Production deployment of `BalanceAdjustment`, two-device delivery-order/duplicate tests, and upgrade-over-App-Store smoke test.

---
