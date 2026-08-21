# Wallets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add wallet support while preserving the current one-wallet experience for new and existing users.

**Architecture:** Introduce a SwiftData `Wallet` model and string wallet ownership fields on transaction-bearing records. A wallet bootstrap/migration service creates `Personal`, assigns legacy records, and preferences resolve the active/default wallet for creation flows. Existing views stay single-wallet by default and reveal wallet controls only after multiple wallets exist.

**Tech Stack:** Swift, SwiftUI, SwiftData, Swift Testing, Xcode project.

**Spec:** `docs/superpowers/specs/2026-08-18-wallets-design.md`

## Global Constraints

- New and existing users start with only one `Personal` wallet.
- Do not auto-create a Side Job wallet.
- Existing data migrates to `Personal` without interrupting the normal app flow.
- `All Wallets` appears only when multiple active wallets exist.
- Use Swift Testing for unit tests and keep tests offline with in-memory SwiftData.

---

### Task 1: Wallet Model, Preferences, And Migration

**Files:**
- Create: `QuickSpend/Models/Wallet.swift`
- Create: `QuickSpend/Models/WalletScope.swift`
- Create: `QuickSpend/Services/WalletService.swift`
- Modify: `QuickSpend/Models/AppSchema.swift`
- Modify: `QuickSpend/Models/Transaction.swift`
- Modify: `QuickSpend/Models/RecurringTemplate.swift`
- Modify: `QuickSpend/Models/BalanceAnchor.swift`
- Modify: `QuickSpend/Services/PreferencesService.swift`
- Modify: `QuickSpend/ViewModels/AppConfigViewModel.swift`
- Modify: `QuickSpend/QuickSpendApp.swift`
- Test: `QuickSpendTests/WalletServiceTests.swift`
- Test: `QuickSpendTests/PreferencesServiceTests.swift`
- Test: `QuickSpendTests/TransactionTests.swift`
- Test: `QuickSpendTests/RecurringTemplateTests.swift`

**Interfaces:**
- Produces: `Wallet.personalID`, `WalletService.bootstrapIfNeeded(modelContext:preferences:)`, `PreferencesService.selectedWalletScopeRawValue`, `PreferencesService.defaultWalletId`.

- [ ] **Step 1: Write failing tests for personal wallet bootstrap, legacy assignment, idempotency, and default wallet preferences.**
- [ ] **Step 2: Run focused tests and verify they fail because wallet APIs do not exist.**
- [ ] **Step 3: Add wallet model, wallet fields, schema registration, preferences, and migration service.**
- [ ] **Step 4: Run focused tests and verify they pass.**
- [ ] **Step 5: Commit task 1.**

### Task 2: Wallet-Aware Balance And Recurring Generation

**Files:**
- Modify: `QuickSpend/Services/BalanceService.swift`
- Modify: `QuickSpend/Services/BalanceCacheStore.swift`
- Modify: `QuickSpend/Services/RecurringService.swift`
- Test: `QuickSpendTests/BalanceServiceTests.swift`
- Test: `QuickSpendTests/BalanceCacheStoreTests.swift`
- Test: `QuickSpendTests/RecurringServiceTests.swift`

**Interfaces:**
- Consumes: `Transaction.walletId`, `RecurringTemplate.walletId`, `BalanceAnchor.walletId`, `Wallet.personalID`.
- Produces: `BalanceService.currentBalance(for:)`, `BalanceService.totalBalance(wallets:)`, wallet-aware optimistic insert/edit/delete overloads.

- [ ] **Step 1: Write failing tests for per-wallet compute, all-wallet total, and recurring wallet copy.**
- [ ] **Step 2: Run focused tests and verify they fail on missing behavior.**
- [ ] **Step 3: Update balance queries/cache keys and recurring generation.**
- [ ] **Step 4: Run focused tests and verify they pass.**
- [ ] **Step 5: Commit task 2.**

### Task 3: Wallet Scope Filtering For Stats And Entry Flows

**Files:**
- Modify: `QuickSpend/Models/PeriodStats.swift`
- Modify: `QuickSpend/Intents/AddExpenseFlow.swift`
- Modify: `QuickSpend/Views/Voice/EditableExpenseDialog.swift`
- Modify: `QuickSpend/Views/TransactionForm/TransactionFormView.swift`
- Test: `QuickSpendTests/PeriodStatsTests.swift`
- Test: `QuickSpendTests/AddExpenseFlowTests.swift`

**Interfaces:**
- Consumes: wallet fields and preferences from Task 1.
- Produces: transaction creation paths that set a wallet ID.

- [ ] **Step 1: Write failing tests for period filtering and App Intent wallet defaulting.**
- [ ] **Step 2: Run focused tests and verify they fail.**
- [ ] **Step 3: Add wallet parameters/defaulting to creation flows.**
- [ ] **Step 4: Run focused tests and verify they pass.**
- [ ] **Step 5: Commit task 3.**

### Task 4: Home, Report, Settings, And Wallet Education UI

**Files:**
- Create: `QuickSpend/Views/Wallets/WalletFormView.swift`
- Create: `QuickSpend/Views/Wallets/WalletManagementView.swift`
- Create: `QuickSpend/Views/Home/WalletWhatsNewModal.swift`
- Modify: `QuickSpend/Views/Home/HomeView.swift`
- Modify: `QuickSpend/Views/Report/ReportDetailView.swift`
- Modify: `QuickSpend/Views/Settings/SettingsView.swift`
- Modify: `QuickSpend/Views/Settings/Sections/PreferencesSection.swift`
- Modify: `QuickSpend/Utilities/L10n.swift`

**Interfaces:**
- Consumes: active wallets, selected wallet scope, default wallet preferences.
- Produces: wallet picker on Home/Report after multiple wallets exist, wallet management, one-time wallet notice.

- [ ] **Step 1: Add Home wallet scope UI gated by multiple active wallets.**
- [ ] **Step 2: Add wallet management and education entry in Settings.**
- [ ] **Step 3: Add one-time wallet what's-new notice for migrated users.**
- [ ] **Step 4: Add Report wallet filter and all-wallet breakdown.**
- [ ] **Step 5: Run Xcode diagnostics/build and fix compile issues.**
- [ ] **Step 6: Commit task 4.**

### Task 5: Full Verification

**Files:**
- No code changes expected.

- [ ] **Step 1: Run focused wallet-related test suites.**
- [ ] **Step 2: Run full project build with Xcode.**
- [ ] **Step 3: Review git diff against spec requirements.**
- [ ] **Step 4: Report verification evidence and remaining gaps.**
