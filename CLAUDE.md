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

- **Models/** — SwiftData `@Model` classes: `Expense`, `QuickCategory`, `RecurringTemplate`, plus supporting value types (`TransactionType`, `RecurrencePattern`, `MonthlyTrend`, `CategoryStats`, `PeriodStats`)
- **ViewModels/** — `@Observable` view models: `AppConfigViewModel` (app settings state), `SubscriptionViewModel` (RevenueCat subscription state)
- **Services/** — Business logic isolated from views. Key services:
  - `GeminiParserService` — AI-powered natural language expense parsing via Firebase AI (Gemini)
  - `VoiceService` — Voice input processing
  - `RecurringService` — Generates expenses from recurring templates
  - `CategoryService` — Seeds and manages expense categories
  - `UsageLimitService` — Enforces free-tier feature limits
  - `PreferencesService` — UserDefaults-backed config storage
  - `AnalyticsService` — Privacy-aware Firebase Analytics (no PII, amount ranges only)
- **Views/** — SwiftUI views organized by feature: Main, Home, Transactions, Settings, Categories, Recurring, ExpenseForm, Voice, Onboarding, Paywall
- **Theme/** — Design system in `AppTheme.swift` (dark forest green primary, 4px spacing base) and `ColorPalette.swift`
- **Utilities/** — `CurrencyFormatter`, `AmountAbbreviator`, `DateRangeHelper`, `AppConstants`, `HomeStrings`

**Entry point:** `QuickSpendApp.swift` → `ContentView.swift` (onboarding gate) → `MainTabView.swift` (3-tab bottom nav: Home, Transactions, Settings)

## Key Conventions

- Firebase and RevenueCat are optional dependencies — use `#if canImport()` for graceful degradation
- Localization supports 6 languages: English, Vietnamese, Japanese, Korean, Thai, Spanish. Translations are currently hardcoded in models (e.g., `QuickCategory` has localized names/keywords) and `HomeStrings.swift`
- Multi-currency support: USD, VND, JPY, KRW, THB, EUR with locale-specific formatting in `CurrencyFormatter`
- Subscription gating: free tier has daily limits (5 AI parses, 3 recurring templates, 7-day reports); pro tier is unlimited. Limits defined in `AppConstants.swift`
- SwiftData models use `@Attribute(.unique)` for IDs and enum raw values for storage
- Private implementation methods use `_` prefix (e.g., `_initializeRevenueCat()`)
