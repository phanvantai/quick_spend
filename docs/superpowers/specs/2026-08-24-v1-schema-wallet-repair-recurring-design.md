# V1 Schema, Wallet Repair, and Recurring Wallet Design

## Goal

Formalize the database schema already shipped on the App Store as schema V1, repair duplicate or incomplete wallet data without losing transactions, and make recurring transaction templates wallet-aware in create and edit flows.

This work must protect users who have run development, TestFlight, and App Store builds against the same CloudKit account and may already have duplicated `Wallet` records.

## Shipped V1 Boundary

V1 is the exact database shape already used by the current App Store build. It includes:

- `Transaction`
- `Category`
- `RecurringTemplate`
- `BalanceAnchor`
- `Wallet`
- the existing `walletId` fields and all other currently persisted fields on those models

The current work does not introduce a structural database change. Therefore it must not create a fake V2 merely to run data repair. A future release creates V2 only when a persisted model, attribute, or relationship changes.

## Schema Versioning

Add `QuickSpendSchemaV1: VersionedSchema` with version identifier `1.0.0` and the current model list. `AppSchema` builds its runtime `Schema` from `QuickSpendSchemaV1` rather than an unversioned model array.

The existing top-level `@Model` declarations become the frozen V1 model definitions. They must not be edited for a future structural change. When a real V2 is needed, V2 receives separate version-owned model declarations and application call sites move to the V2 types; V1 continues referencing the unchanged shipped types. This avoids changing model namespaces during the V1 adoption and protects compatibility with the existing App Store entity identities.

Add `QuickSpendMigrationPlan: SchemaMigrationPlan` with:

- `schemas = [QuickSpendSchemaV1.self]`
- no migration stages, because there is no structural version transition yet

Every production and App Intent `ModelContainer` must receive this migration plan. CloudKit Development schema initialization must use the same V1 model list so runtime and CloudKit schema definitions cannot drift.

The app must continue opening the existing unversioned App Store store in place. Failure to open the existing store is a release blocker; the app must never delete or replace the user's store as a migration fallback.

Record the V1 schema version and entity names in a compatibility test so an accidental edit to a frozen V1 model is caught before release.

## V1 Data Repair

Schema migration and data repair are separate concerns. V1 data repair runs after the store opens and remains idempotent so it is safe on every launch and after repeated CloudKit imports.

The repair performs these operations in one model context:

1. Group wallets by business ID.
2. For duplicate IDs, retain one canonical wallet:
   - prefer a record whose metadata was edited after creation;
   - among edited records, prefer the most recently edited;
   - otherwise prefer the oldest seed record.
3. Delete the other duplicate wallet rows and save the deletion so CloudKit can propagate it.
4. Ensure the fixed `wallet_personal` wallet exists.
5. Preserve all transaction references. Transactions use string `walletId`, so removing duplicate wallet rows must not rewrite or delete transactions.
6. Preserve the existing legacy transaction and balance-anchor backfill behavior.
7. For a recurring template whose `walletId` is empty or references no active wallet, assign the resolved active default wallet. If the stored default is missing or archived, fall back to Personal.

The repair must not overwrite a recurring template that already references an active wallet. Running it twice must produce no additional changes on the second run.

## CloudKit Timing

The app-level container bootstrap can run before CloudKit restores remote records, so it is not sufficient by itself.

V1 data repair runs at all of these points:

- immediately after `ModelContainer` creation for local data;
- after Splash confirms the initial CloudKit import has completed;
- after later CloudKit import completion events.

This closes the race where a local Personal wallet is seeded first and a second remote Personal wallet arrives later. Import-event delivery is not assumed to replay, so the post-initial-import Splash call remains required.

Migration failures must be logged with the failing phase and retried at the next repair point. The app remains usable, but it must not report a failed data save when persistence succeeded and only a cache refresh failed.

## Recurring Transaction Wallet UX

`RecurringListView` queries active wallets and resolves the default wallet through the same `WalletService` rules as the normal transaction form.

`RecurringFormView` receives:

- active wallets;
- resolved default wallet ID;
- an optional existing template.

Selection rules:

1. Editing starts with the existing template's active wallet.
2. If the existing wallet is missing, empty, or archived, use the resolved default wallet.
3. Creating starts with the resolved default wallet.
4. Show the wallet picker only when more than one active wallet exists, matching the normal transaction form.

Saving a new template persists the selected `walletId`. Saving an edit copies the selected `walletId` back to the existing template together with the other editable fields.

`RecurringService` already copies `RecurringTemplate.walletId` into newly generated transactions; that contract remains unchanged. Changing a template's wallet affects only future generated transactions. Previously generated transactions retain their existing wallet assignment.

## Balance UX Included in This Branch

The already-approved balance changes remain part of the same branch:

- remove the standalone Settings balance editor;
- remove quick balance editing from Home;
- tapping the Home balance opens wallet management;
- wallet edit contains balance editing;
- saving an untouched formatted balance must not move its anchor date.

These changes do not alter the persisted schema and therefore remain within V1.

## Error Handling and Data Safety

- Never delete the persistent store to recover from a migration failure.
- Never infer transaction ownership from a duplicated wallet object's persistent identifier; business ownership remains the string `walletId`.
- Never rewrite an already-valid recurring template wallet during repair.
- A failed pre-import repair is retried after initial import.
- A failed post-import repair is logged and retried on the next import or launch.
- Wallet form and recurring form save errors keep the form open and present an error.
- CloudKit schema initialization remains an explicit DEBUG-only operation and is not treated as a local migration.

## Testing

### Schema Compatibility

Add an on-disk migration test that:

1. creates a temporary SQLite store with the existing unversioned App Store schema;
2. inserts representative transactions, categories, recurring templates, balance anchors, and wallets;
3. closes the original container;
4. opens the same store using `QuickSpendSchemaV1` and `QuickSpendMigrationPlan`;
5. verifies every record and wallet reference is preserved.

This test must use a real temporary on-disk store rather than an in-memory container.

### V1 Data Repair

Add SwiftData regression tests for:

- duplicate Personal wallets collapse to one canonical wallet;
- customized wallet metadata wins over a later unedited seed;
- transaction count, amount, and `walletId` remain unchanged;
- an empty recurring wallet migrates to the active configured default;
- a missing or archived recurring wallet falls back to the resolved active default;
- an already-valid recurring wallet remains unchanged;
- a second repair run produces no additional changes.

### Recurring Wallet Flow

Add tests for:

- a new recurring template defaults to the resolved default wallet;
- editing starts from the template's current wallet;
- saving an edit changes `walletId`;
- generated transactions copy the edited template wallet;
- only active wallets are selectable.

### Final Verification

- Run the focused schema, wallet, recurring, balance, and formatting suites.
- Run the full `QuickSpendTests` target on an iOS Simulator.
- Run an iOS Simulator build with no warnings.
- Run `git diff --check`.
- Perform an independent final code review before merge.

## Release and CloudKit Checks

Before shipping:

- initialize and inspect the V1-compatible schema in CloudKit Development;
- verify duplicate-wallet deletion propagation between two test devices or accounts;
- confirm the Production CloudKit schema already contains every V1 field before release;
- smoke-test an upgrade over an App Store installation without deleting the app.

CloudKit Development initialization and Production schema deployment are operational release steps, not runtime migrations.

## Out of Scope

- Creating schema V2 without a structural model change.
- Reassigning previously generated transactions when a recurring template's wallet changes.
- Wallet-to-wallet transfers.
- Per-wallet recurring schedules or category sets.
- Deleting user data as a migration recovery strategy.
- Publishing, deploying, or merging without explicit authorization.
