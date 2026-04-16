# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

QuickSpend is a native iOS expense tracking app built with SwiftUI and SwiftData. It supports voice-to-expense input via speech recognition + Gemini AI parsing, recurring transactions, multi-language support (en/vi/ja/es), and a freemium subscription model via RevenueCat.

- **Bundle ID:** `com.randomtech.quickSpend`
- **Deployment target:** iOS 18.0
- **Swift version:** 5.0
- **Dependencies (SPM):** Firebase iOS SDK (Analytics, AI/Gemini), RevenueCat

## Build & Test

```bash
# Build
xcodebuild -project QuickSpend.xcodeproj -scheme QuickSpend -sdk iphonesimulator build

# Run all tests
xcodebuild -project QuickSpend.xcodeproj -scheme QuickSpend -sdk iphonesimulator test

# Run a single test
xcodebuild -project QuickSpend.xcodeproj -scheme QuickSpend -sdk iphonesimulator \
  -only-testing:QuickSpendTests/TransactionTests test
```

Open in Xcode: `open QuickSpend.xcodeproj`

## Architecture

### Data Layer

- **SwiftData** models: `Transaction`, `Category`, `RecurringTemplate` — registered in `QuickSpendApp.modelContainer`
- **UserDefaults** via `PreferencesService` (singleton) stores `AppConfig` as JSON — holds language, currency, theme, onboarding state
- Categories are linked to transactions via `categoryId` string (not a SwiftData relationship)

### State Management

- `AppConfigViewModel` (`@Observable`) — wraps `PreferencesService`, injected as `@Environment` from app root
- `SubscriptionViewModel` (`@Observable`) — RevenueCat integration, also `@Environment`
- Both are created in `QuickSpendApp` and passed down via `.environment()`

### Services (`Services/`)

- `CategoryService` — seeds default categories on first launch, updates names on language change
- `RecurringService` — generates pending transactions from active templates on app startup
- `GeminiParserService` — AI expense parsing via Firebase AI (Gemini 2.5 Flash). Compiles with `#if canImport(FirebaseAI)` guards; falls back gracefully when SDK is absent
- `VoiceService` (`@Observable`) — `SFSpeechRecognizer` + `AVAudioEngine` for live transcription
- `UsageLimitService` (`@Observable`) — daily Gemini parse limit tracking, auto-resets each day
- `AnalyticsService` — Firebase Analytics wrapper with `#if canImport(FirebaseAnalytics)` guards
- `PreferencesService` — singleton for UserDefaults-backed app config

### View Hierarchy

```bash
QuickSpendApp
└── ContentView (routes onboarding vs main)
    ├── OnboardingView
    └── MainTabView (3 tabs + floating voice FAB)
        ├── Tab 0: HomeView (summary, overview, trends, report sections)
        ├── Tab 1: TransactionsView (calendar grid + list)
        ├── Tab 2: SettingsView (categories, recurring, preferences)
        └── VoiceFABButton → VoiceOverlay → EditableExpenseDialog
```

### Localization

- Uses Apple String Catalogs (`Localizable.xcstrings`) with 4 languages: en, vi, ja, es
- `L10n.tr(key, language)` resolves strings for the user-selected language (not system locale)
- Category names are localized in `CategoryService.categoryName(for:language:)`

### Design System (`Theme/`)

- `AppTheme` — colors (dark forest green primary), gradients, 4px-based spacing, border radii
- `ColorPalette` — `Color(hex:)` extension for hex string colors
- Reusable components in `Views/Components/`: `PickerSheet`, `SettingSelectionRow`, `CardBackground`, `CategoryIconBadge`, `EmptyDataView`, `TransactionTypePicker`, `ChangeBadge`

### Freemium Model

- Free tier limits: 5 Gemini parses/day, 3 recurring templates, 7-day reports
- Pro via RevenueCat (`SubscriptionViewModel`), gated with `#if canImport(RevenueCat)`
- Constants in `AppConstants`

### Conditional SDK Pattern

Firebase and RevenueCat integrations use `#if canImport(...)` so the app builds and runs without these SDKs (features degrade gracefully). Keep this pattern when adding new SDK-dependent code.

## Testing (MANDATORY)

This project follows **Test-Driven Development (TDD)**. Tests are not optional.

- **Every code change must include corresponding tests.** No exceptions.
- Write tests **before or alongside** implementation code — never skip them.
- Test files live in `QuickSpendTests/` and follow the naming convention `<ClassName>Tests.swift`.
- Cover all services, view models, models, and any logic-bearing code with unit tests.
- Use `@Test` and `#expect` (Swift Testing framework) for new tests.
- **Always use mock data in tests — never use real data.** This includes:
  - Use mock/stub services instead of real service singletons (e.g., never call `PreferencesService.shared` directly; inject a mock or use a test-specific `UserDefaults` suite).
  - Use in-memory `ModelContainer` / `ModelConfiguration(isStoredInMemoryOnly: true)` for SwiftData tests — never read from or write to the real database.
  - Use hardcoded test fixtures (fake transactions, categories, templates) with clearly artificial values — never reference real user data, real API keys, or production identifiers.
  - Mock external dependencies (Firebase, RevenueCat, network calls) — tests must run offline and without any real backend. Always introduce a protocol abstraction layer (e.g., `SubscriptionProvider`) between your code and third-party SDKs so tests can inject a mock implementation instead of calling the SDK directly.
  - Each test must be fully isolated: set up its own mock data in `init()` or a setup method, and not depend on state from other tests.
- Run tests after every change to verify nothing is broken:

  ```bash
  xcodebuild -project QuickSpend.xcodeproj -scheme QuickSpend -sdk iphonesimulator test
  ```

- If a bug is fixed, add a regression test that reproduces the bug first.

## Changelog & Release Notes

- Changelog is tracked in `CHANGELOG.md` at the project root.
- Every release entry must include App Store release notes in **all 4 languages: en, vi, ja, es**.
- Format for each release:

```
## [version] - YYYY-MM-DD

### What's New
- Feature 1

### Bug Fixes
- Fix 1

### Improvements
- Improvement 1 (optional)

### App Store Notes
#### en
What's New
• ...
Bug Fixes
• ...

#### vi
Tính năng mới
• ...
Sửa lỗi
• ...

#### ja
新機能
• ...
バグ修正
• ...

#### es
Novedades
• ...
Correcciones
• ...
```
