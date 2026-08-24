# Balance Adjustment Ledger and Schema V2 Design

## Goal

Make wallet balances remain correct when users manually reconcile approximate transaction history and later create, edit, move, or delete transactions. A pure wallet move must update both wallet balances while preserving the combined total, regardless of when the transaction or the latest balance confirmation was created.

This is the first real persisted schema change after the shipped App Store shape was frozen as V1. It introduces schema V2 and must upgrade an existing unversioned App Store store in place without deleting or replacing it.

## Product Semantics

QuickSpend is not a complete bank ledger. Users may round transaction amounts, omit small transactions, and periodically enter the balance they observe in reality. A manual balance edit is therefore an authoritative reconciliation, not proof that every earlier transaction is exact.

The balance contract becomes:

```text
current balance
= opening balance at the wallet's baseline anchor
+ signed transactions created on or after that anchor
+ all signed balance adjustments for that wallet
```

`BalanceAnchor` retains these meanings:

- `openingBalance` is the baseline carried from the latest V1 reconciliation at upgrade, or confirmed when balance tracking first starts for a V2 wallet.
- `anchorDate` is the cutoff that prevents incomplete history from before balance tracking from being counted.

After V2, editing an already-configured wallet balance does not move `anchorDate` or replace `openingBalance`. Instead, it appends a signed `BalanceAdjustment` equal to `desiredBalance - currentBalance`.

Adjustments are always included for their wallet. They are not filtered by `anchorDate`: an adjustment can only be created after the wallet has an anchor, and unconditional inclusion avoids client-clock and CloudKit delivery-order errors.

## Chosen Approach

Add an immutable adjustment ledger rather than silently mutating `BalanceAnchor.openingBalance` during transaction edits.

This preserves distinct concepts:

- anchors establish the starting boundary;
- transactions describe user-entered financial events;
- adjustments reconcile the computed ledger with observed reality or compensate for edits to history that is outside the anchor boundary.

Rejected alternatives:

1. Mutating `openingBalance` to compensate for transaction edits needs no schema change, but destroys the meaning of the user-confirmed baseline and leaves no audit trail.
2. Moving `anchorDate` on every transaction edit can exclude late CloudKit imports and repeats the current failure mode.
3. Counting all historical transactions removes the anchor's protection against incomplete pre-install history.

## Schema V2

Add a CloudKit-compatible `BalanceAdjustment` model with non-unique business identifiers:

- `id: String` — immutable row business ID;
- `operationId: String` — shared by adjustments produced by the same user action;
- `walletId: String` — affected wallet business ID;
- `amount: Double` — signed delta applied to the wallet balance;
- `reason: String` — persisted raw value such as `manual_reconciliation`, `transaction_edit`, or `transaction_delete`;
- `sourceTransactionId: String?` — transaction associated with an edit/delete adjustment;
- `createdAt: Date` — audit and display timestamp, not an inclusion cutoff.

All persisted properties receive CloudKit-compatible defaults. No `@Attribute(.unique)` constraint is introduced.

`QuickSpendSchemaV2` uses version `2.0.0` and contains the unchanged five V1 entity types plus `BalanceAdjustment`. V1's model list and checked-in 47-attribute signature remain unchanged. Because V2 only adds an entity, existing top-level V1 model types may be reused without changing their persisted metadata; any future modification to an existing entity requires version-owned model declarations.

`QuickSpendMigrationPlan` becomes:

- schemas: V1, V2;
- stages: one lightweight V1-to-V2 migration.

`AppSchema` uses V2 for every production, fallback, DEBUG CloudKit, and App Intent container.

The migration must support both upgrade paths:

1. a versioned V1 store to V2;
2. the currently shipped unversioned App Store store, whose exact shape is V1, opening directly under the V1/V2 migration plan and becoming V2.

There is no store-deletion fallback.

## Balance Computation

For a wallet with an anchor:

1. Fetch transactions whose `createdAt >= anchor.anchorDate` and whose `walletId` matches.
2. Sum income positively and expense negatively.
3. Fetch every `BalanceAdjustment` whose `walletId` matches and sum `amount` without a date predicate.
4. Return `anchor.openingBalance + transactionDelta + adjustmentDelta`.

For a wallet without an anchor, return `nil` even if transactions or adjustments exist. Application code must never create an adjustment for a wallet without an anchor.

The existing observable per-wallet balance publication and debounced reconciliation remain. A successful mutation publishes the target balances immediately; the next recompute must produce identical values.

## Manual Balance Reconciliation

`setCurrentBalance` follows two branches:

- No anchor exists: create the wallet's first `BalanceAnchor` with the entered amount and current time, exactly as V1 does.
- An anchor exists: compute the authoritative current balance and insert one `manual_reconciliation` adjustment for `enteredAmount - currentBalance`. Do not modify the anchor.

If the delta is zero within the currency-normalized comparison already used by the wallet form, do not create an adjustment.

The adjustment and any wallet metadata edit save together. A failure keeps the form open, restores in-memory values, and reports the error. A successful persistence followed by a cache refresh failure must not be reported as a failed save.

## Transaction Mutation Reconciliation

Transaction mutation uses balances observed immediately before the mutation as the source of truth. Timestamp comparison is an implementation detail of the normal transaction formula, never the product rule for deciding whether a balance changes.

Let `signed(amount, type)` return positive income or negative expense.

### Edit Within One Wallet

```text
target = balanceBefore + signed(new) - signed(old)
```

Changing only note, category, or display date produces no balance adjustment.

### Move Between Wallets

```text
sourceTarget      = sourceBalanceBefore - signed(old)
destinationTarget = destinationBalanceBefore + signed(new)
```

For a pure wallet move with unchanged amount and type, the sum of both wallet targets equals the sum before the edit.

### Delete

```text
target = balanceBefore - signed(deleted transaction)
```

### Persisting the Targets

For each affected wallet that has an established balance:

1. Capture its authoritative balance before mutation.
2. Calculate the literal target using the formulas above.
3. Apply the transaction edit or pending deletion in memory.
4. Recompute the wallet using the existing anchor, transactions, and existing adjustments, excluding adjustments for the current operation.
5. Insert a new adjustment for `target - recomputedBalance` only when the difference is non-zero.
6. Save the transaction mutation and all operation adjustments in one explicit `ModelContext.save()`.
7. Publish the target balances only after save succeeds.

Adjustments created for one mutation share an `operationId`. Their row IDs are deterministic within that operation, for example `<operationId>:<walletId>`, so retry and CloudKit duplicate repair can identify duplicates.

Create operations normally need no adjustment because a newly created transaction is after an existing anchor. They continue through explicit persistence and normal balance publication.

## Atomicity and Error Handling

Introduce a transaction persistence boundary rather than letting the form depend on eventual SwiftData autosave.

- The transaction form's save callback is throwing.
- The form dismisses only after the callback succeeds.
- An edit snapshots every mutable transaction field before applying changes.
- The persistence operation snapshots affected anchor/adjustment state needed for restoration.
- On failure, inserted adjustments are removed, edited transaction fields are restored, pending deletion is undone, original published balances are restored, and the form remains open with a localized error.
- A failed delete closes no data-loss gap: the row is restored and `TransactionsView` presents a localized error from the existing screen.
- Do not roll back the entire shared `ModelContext`, because that could discard unrelated changes.

The implementation must prove create, edit, move, and delete durability by closing and reopening an on-disk store.

## CloudKit and Idempotence

`BalanceAdjustment` rows are immutable after successful creation. CloudKit imports may deliver an operation more than once or in a different order from its transaction/anchor.

V2 data repair runs at the same three trigger points as wallet repair:

- container open;
- initial CloudKit import completion;
- later CloudKit import events.

It groups adjustments by `id`, retains one deterministic canonical row, and deletes duplicate rows. It never merges different operation IDs, even if their amounts and source transaction IDs match.

Computation is order-independent: once an anchor exists, every adjustment for the wallet is included. A temporarily missing transaction or adjustment is corrected by the next CloudKit import and debounced recompute.

## Existing Incorrect Edits

V1 did not persist a previous wallet ID or mutation audit, so V2 migration cannot safely infer the source wallet for edits that already completed under V1. It must not guess or hard-code a repair based on amount, timestamp, or note.

Affected users perform one authoritative balance reconciliation per wallet after upgrading. Under V2, those corrections become explicit adjustments and future transaction edits remain consistent. Product release notes or an in-app one-time notice may explain this if the issue affected a released build.

## Testing

### Schema and Migration

- V1's exact 47-attribute signature remains unchanged.
- V2 adds only the expected `BalanceAdjustment` entity and fields.
- A real on-disk versioned V1 store opens as V2 with all original data intact.
- A real on-disk unversioned shipped-shape store opens directly under the V2 runtime plan with all original data intact.
- No test or recovery path deletes the store.

### Balance Semantics

- First balance setup creates an anchor.
- Later manual balance edits create signed adjustments and leave `openingBalance` and `anchorDate` unchanged.
- Adjustment computation is independent of adjustment timestamp.
- Wallets without anchors remain `nil` and receive no adjustments.
- Duplicate adjustment IDs are repaired idempotently.

### Transaction Mutations

Use literal expected balances for:

- Personal to another wallet;
- another wallet to Personal;
- one non-Personal wallet to another;
- a transaction older than both wallet anchors;
- a transaction newer than both anchors;
- different anchor dates on source and destination;
- amount and income/expense changes within one wallet;
- moving while changing amount/type;
- deleting an old and a new transaction;
- note/category/date-only edits producing no adjustment;
- pure wallet moves preserving the combined balance;
- failed saves restoring transaction, adjustments, and published balances;
- successful edit/delete surviving an on-disk close and reopen;
- authoritative recompute matching the optimistic published target.

### Final Verification

- Focused schema, balance, transaction persistence, wallet, and CloudKit tests.
- Full `QuickSpendTests` on the fixed iOS Simulator.
- Warning-free simulator build.
- `git diff --check`.
- Independent code review before merge.

## Release Gates

- Initialize and inspect the V2 CloudKit Development schema.
- Deploy the new `BalanceAdjustment` record type to Production before releasing the V2 app.
- Test an upgrade over the current App Store installation without deleting the app.
- Test adjustment and transaction delivery in both orders across two devices.
- Test duplicate adjustment repair and combined-wallet total preservation across two devices.

These are manual release validations, not claims made by local tests.

## Out of Scope

- Automatically guessing the previous wallet for transaction edits completed before V2.
- Bank integrations or exact bank-statement reconciliation.
- Currency conversion between wallets.
- Changing historical transaction dates to force inclusion.
- Deleting or replacing a persistent store after migration failure.
- Publishing, merging, or deploying without explicit authorization.
