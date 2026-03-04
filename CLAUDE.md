# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

QuickSpend is a native iOS expense tracking app built with SwiftUI and SwiftData. Recently migrated from Flutter to SwiftUI. Targets iOS 17+ using modern Swift concurrency and the `@Observable` macro.

## Build & Run

```bash
# Open in Xcode
open QuickSpend.xcodeproj

# Build from command line
xcodebuild -scheme QuickSpend -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run on simulator
xcodebuild -scheme QuickSpend -destination 'platform=iOS Simulator,name=iPhone 16' run
```

Dependencies are managed via Swift Package Manager (resolved in the Xcode project, no standalone Package.swift). Key dependencies: Firebase SDK v12.9.0 (Analytics, Firestore, FirebaseAI/Gemini, Cloud Messaging) and RevenueCat (subscriptions).

## Architecture

**Pattern:** MVVM with service layer

- **Models/** — SwiftData `@Model` classes: `Transaction`, `Category`, `RecurringTemplate`, plus supporting value types (`TransactionType`, `RecurrencePattern`, `CategoryGroup`, `MonthlyTrend`, `CategoryStats`, `PeriodStats`)
- **ViewModels/** — `@Observable` view models: `AppConfigViewModel` (app settings state), `SubscriptionViewModel` (RevenueCat subscription state)
- **Services/** — Business logic isolated from views. Key services:
  - `GeminiParserService` — AI-powered natural language transaction parsing via Firebase AI (Gemini). Returns `ParsedTransaction` structs
  - `VoiceService` — Voice input processing
  - `RecurringService` — Generates transactions from recurring templates (supports daily/weekly/monthly/yearly patterns)
  - `CategoryService` — Seeds and manages categories (26 default: 18 expense + 8 income, EN/VI localized)
  - `UsageLimitService` — Enforces free-tier feature limits
  - `PreferencesService` — UserDefaults-backed config storage
  - `AnalyticsService` — Privacy-aware Firebase Analytics (no PII, amount ranges only)
- **Views/** — SwiftUI views organized by feature: Main, Home, Transactions, Settings, Categories, Recurring, ExpenseForm, Voice, Onboarding, Paywall
- **Theme/** — Design system in `AppTheme.swift` (dark forest green primary, 4px spacing base) and `ColorPalette.swift`
- **Utilities/** — `CurrencyFormatter`, `AmountAbbreviator`, `DateRangeHelper`, `AppConstants`, `HomeStrings`

**Entry point:** `QuickSpendApp.swift` → `ContentView.swift` (onboarding gate) → `MainTabView.swift` (3-tab bottom nav: Home, Transactions, Settings)

## Database Models (v2)

### Transaction (`@Model`)

- `id: String` (unique), `amount: Double`, `note: String`, `categoryId: String`, `type: TransactionType` (Codable enum, auto-encoded), `date: Date`, `rawInput: String?`, `confidence: Double?`, `createdAt: Date`, `updatedAt: Date`
- Computed: `isIncome`, `isExpense`
- Replaces old `Expense` model (v1)

### Category (`@Model`)

- `id: String` (unique, e.g. `"food_drink"`), `name: String`, `iconName: String`, `colorHex: String`, `type: TransactionType`, `group: CategoryGroup?`, `sortOrder: Int`, `isHidden: Bool`, `createdAt: Date`, `updatedAt: Date`
- Computed: `color: Color` (from hex), `isIncomeCategory`, `isExpenseCategory`
- Replaces old `QuickCategory` model (v1). No more `isSystem` distinction
- Relationship to Transaction via string-based `categoryId` (no `@Relationship`)

### RecurringTemplate (`@Model`)

- `id: String`, `amount: Double`, `note: String`, `categoryId: String`, `type: TransactionType`, `pattern: RecurrencePattern` (daily/weekly/monthly/yearly), `startDate: Date`, `endDate: Date?`, `isActive: Bool`, `lastGeneratedDate: Date?`, `createdAt: Date`, `updatedAt: Date`

### Enums

- `TransactionType`: `.income`, `.expense` — Codable, stored directly by SwiftData
- `RecurrencePattern`: `.daily`, `.weekly`, `.monthly`, `.yearly` — Codable
- `CategoryGroup`: `.dailyLiving`, `.personal`, `.social`, `.financial`, `.earned`, `.passive`, `.received`, `.other`

### Migration Strategy

- **Clean Start**: v1→v2 deletes old SwiftData store via `_resetStoreIfNeeded()` in `QuickSpendApp.swift`
- Uses `UserDefaults` flag `hasCompletedV2Migration`
- Categories re-seeded on fresh start via `CategoryService.seedCategoriesIfNeeded()`

## Key Conventions

- Firebase and RevenueCat are optional dependencies — use `#if canImport()` for graceful degradation
- Localization supports 4 languages: English (en), Vietnamese (vi), Japanese (ja), Spanish (es). Category names defined in `CategoryService.swift`, UI strings in `HomeStrings.swift`
- AI category matching: `GeminiParserService` sends category ID + localized name to Gemini, which returns the matched ID directly. No keywords needed — Gemini understands category context from names alone
- Multi-currency support: USD, VND, JPY, EUR with locale-specific formatting in `CurrencyFormatter`
- Subscription gating: free tier has daily limits (5 AI parses, 3 recurring templates, 7-day reports); pro tier is unlimited. Limits defined in `AppConstants.swift`
- SwiftData models use `@Attribute(.unique)` for IDs and Codable enums stored directly (no raw value wrappers)
- Private implementation methods use `_` prefix (e.g., `_initializeRevenueCat()`, `_resetStoreIfNeeded()`)
- Default category IDs follow snake_case pattern: `food_drink`, `other_expense`, `salary`, `investment_income`, etc.
- **Reusable Views**: Always extract repeated UI patterns into reusable SwiftUI components in `Views/Components/`. Prefer generic, composable views (e.g., `SettingSelectionRow`, `PickerSheet`) over duplicating UI code across features. Check existing components before creating new ones.
