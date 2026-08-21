# Wallets Design

## Goal

Add wallet support so users can separate personal money from other money streams, such as side-job income and side-job expenses, without making first-time setup heavier.

The first version must preserve the current single-ledger experience by default. New and existing users start with one `Personal` wallet. Users can create more wallets when they need separate tracking.

## User Experience

### New Users

- On first launch, the app creates one default wallet: `Personal`.
- The app behaves like the current version while only one wallet exists.
- Home does not need to show a wallet scope picker when there is only one wallet.
- New transactions default to `Personal`.
- A lightweight education entry appears in Settings or a contextual card:
  - "Create another wallet to separate side income, trips, or project expenses."
- The app does not add a Side Job wallet automatically and does not add a required wallet setup step to onboarding.

### Existing Users Updating The App

- On first launch after the update, the app runs an idempotent migration.
- The migration creates the `Personal` wallet if it does not already exist.
- Existing transactions, recurring templates, and balance anchor data are assigned to `Personal`.
- The app keeps the existing workflow visually close to the previous version because there is still only one wallet.
- After migration succeeds, the app shows a one-time what's-new notice:
  - Existing data is now in `Personal`.
  - Wallets can be created to separate side income, project costs, travel, or similar streams.
  - The notice has a dismiss action and an optional "Create Wallet" action.

### Multiple Wallets

Once the user has more than one active wallet:

- Home shows a wallet scope control:
  - `All Wallets`
  - each active wallet
- The app remembers the last selected Home wallet scope.
- Transaction forms include a wallet field.
- Reports include a wallet filter and default to the current Home scope.
- Settings includes wallet management and a default-wallet preference.

## Default Wallet Rules

The app stores:

- `selectedWalletScope`: the user's last Home scope.
- `defaultWalletId`: the wallet used when a transaction is created without a specific wallet context.

Default transaction wallet resolution:

1. If the user opens the transaction form from a specific wallet scope, use that wallet.
2. If the user opens the transaction form from `All Wallets`, use `defaultWalletId`.
3. If `defaultWalletId` is missing or archived, fall back to `Personal`.

The default wallet starts as `Personal`.

## Data Model

Add a `Wallet` SwiftData model:

- `id: String`
- `name: String`
- `iconName: String`
- `colorHex: String`
- `sortOrder: Int`
- `isArchived: Bool`
- `createdAt: Date`
- `updatedAt: Date`

Use fixed IDs for built-in data:

- `wallet_personal`

Add wallet ownership fields:

- `Transaction.walletId: String`
- `RecurringTemplate.walletId: String`
- `BalanceAnchor.walletId: String`

Balance anchors become wallet-scoped. A wallet can have zero or one active anchor. `Personal` receives the migrated existing anchor.

## Migration

The migration must be idempotent:

- Create `wallet_personal` only if missing.
- Assign records with missing or empty `walletId` to `wallet_personal`.
- Convert the existing singleton balance anchor into the `Personal` wallet anchor.
- Do not overwrite records that already have a wallet assignment.
- Store a preference flag after successful migration so the one-time notice is shown only once.

CloudKit sync can replay or merge data, so migration and seed logic must tolerate duplicate or partially migrated local state.

## Home Behavior

With one active wallet:

- Home behaves like today.
- It filters implicitly to `Personal`.
- No wallet picker is required.

With multiple active wallets:

- Home can show `All Wallets` or one specific wallet.
- Monthly totals, summary pills, charts, and report links use the selected scope.
- `All Wallets` aggregates all active wallets.
- Specific wallet scopes show only that wallet's transactions and balance.

## Balance Behavior

Balance is wallet-scoped:

- A specific wallet shows that wallet's computed balance.
- `All Wallets` shows the sum of balances for active wallets that have anchors.
- If a wallet has no anchor, its transaction stats still work, but balance setup remains optional.

Optimistic balance updates must apply only to the affected wallet. Edits that move a transaction between wallets subtract from the old wallet and add to the new wallet.

## Reports

Reports get a wallet filter:

- Default filter follows the current Home scope.
- `All Wallets` includes an additional wallet breakdown.
- Specific wallet reports use the existing income, expense, category, and trend breakdowns.

For a side-job wallet, the existing `netBalance = income - expenses` is the side-job profit. No special model is needed in v1.

## Transaction Entry

Manual transaction form:

- Shows a wallet field only when multiple active wallets exist.
- Defaults according to the default wallet rules.
- Editing an existing transaction always starts with the transaction's wallet.

Voice review:

- Shows a wallet field when multiple active wallets exist.
- Defaults each parsed transaction according to the same rules.

App Intents:

- V1 can save into `defaultWalletId`, falling back to `Personal`.
- Wallet selection in Siri can be added later as a separate enhancement.

Recurring templates:

- Include `walletId`.
- Generated transactions copy the template wallet.

## Error Handling

- If a transaction references an archived or missing wallet, keep the transaction readable and show it under `Personal` fallback only for display/filter safety.
- If migration fails, keep the app usable and retry on next launch.
- If duplicate `Personal` wallets appear through sync, keep the fixed-ID wallet and avoid assigning new data to duplicates.

## Testing

Add Swift Testing coverage for:

- New install seed creates only `Personal`.
- Existing transactions with missing wallet IDs migrate to `Personal`.
- Migration is idempotent.
- Default wallet resolution from specific wallet, `All Wallets`, missing default, and archived default.
- Period stats filtered by wallet scope.
- Balance computation per wallet and `All Wallets`.
- Recurring generation copies wallet IDs.

Add UI test coverage for:

- Existing single-wallet flow still allows adding a transaction without choosing a wallet.
- Creating a second wallet reveals wallet selection on Home and transaction form.

## Out Of Scope For V1

- Automatically creating a `Side Job` wallet.
- Per-wallet category sets.
- Wallet-to-wallet transfers.
- Siri wallet disambiguation.
- Budgets per wallet.
