# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

QuickSpend is a native iOS expense tracking app built with SwiftUI. It uses voice input and AI (Google Gemini) to convert speech to structured expenses. The app is monetized via RevenueCat subscriptions.

**Tech Stack**: SwiftUI + SwiftData + Firebase (Analytics + Gemini AI) + RevenueCat

## Build & Run

Open the project in Xcode:

```bash
open QuickSpend.xcodeproj
```

Build from CLI:

```bash
xcodebuild -project QuickSpend.xcodeproj -scheme QuickSpend -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16'
```

**No CocoaPods or SPM CLI setup needed** — dependencies (Firebase, RevenueCat) are managed through Xcode's Swift Package Manager integration and are already configured in the `.xcodeproj`.

## Architecture

### MVVM + Service-Oriented

- **Models/** — SwiftData `@Model` classes: `Expense`, `QuickCategory`, `RecurringTemplate`. `AppConfig` is a plain `Codable` struct (not persisted in SwiftData).
- **ViewModels/** — `@Observable` classes: `AppConfigViewModel` (language/currency/theme), `SubscriptionViewModel` (RevenueCat/premium state).
- **Services/** — Domain-specific logic classes/enums injected or called directly from ViewModels and Views.
- **Views/** — Feature-based folders. Tab navigation is in `Views/Main/MainTabView.swift`. Root routing (onboarding vs main app) is in `ContentView.swift`.

### Key Data Flow

1. `QuickSpendApp.swift` sets up the SwiftData `ModelContainer` with all three models and injects `AppConfigViewModel` and `SubscriptionViewModel` into the environment.
2. `ContentView.swift` reads `appConfig.isOnboardingComplete` to route to `OnboardingView` or `MainTabView`.
3. Views access `modelContext` via `@Environment(\.modelContext)` for SwiftData queries.
4. `AppConfigViewModel` and `SubscriptionViewModel` are accessed via `@Environment` throughout.

### AI Expense Parsing

`GeminiParserService` builds a context-aware prompt (categories, current date, language) and calls Firebase Gemini 2.5 Flash. It parses shorthand amounts (e.g., "50k" → 50000, Vietnamese "1m5" → 1,500,000). The service is gated: free tier gets 5 parses/day (tracked in `UsageLimitService`), pro tier gets unlimited.

### Feature Gating

`SubscriptionViewModel.isPremium` controls access. Limits are defined in `Utilities/AppConstants.swift`:

- Free: 5 Gemini parses/day, 3 recurring templates, 7-day report history
- Premium: 999 (effectively unlimited)

### Conditional Compilation

Firebase and RevenueCat imports are wrapped in `#if canImport(...)` guards throughout the codebase so the app builds and runs without these SDKs (with degraded functionality).

## Localization

The app supports 6 languages (EN, VI, JA, KO, TH, ES) and 6 currencies (USD, VND, JPY, KRW, THB, EUR). Language/currency selection is stored in `AppConfig` via `PreferencesService` (UserDefaults). System category names are seeded per-language in `CategoryService`.

## Theme & Design System

Design tokens live in `Theme/AppTheme.swift`. Dark mode is supported via `themeMode` in `AppConfig`.

**Color Palette:**

- **Primary brand**: Dark forest green `#1B4332` (tab tint, FAB, selected segments, income bars)
- **Primary light/dark**: `#2D6A4F` / `#143D29`
- **Expense semantic**: Red `#C0392B` (transaction amounts), Gold/amber `#B8860B` (chart bars/lines)
- **Income semantic**: Green `#27AE60` (transaction amounts), Dark green `#1B4332` (chart bars/lines)
- **Accents**: Teal `#00897B`, Coral `#E57373`, Amber `#FFB74D` (settings/onboarding icons)
- **Background**: Light mint gradient `#E8F5E9` → white at top of screens

**Layout Patterns:**

- 4px-based spacing system (4, 8, 12, 16, 20, 24, 32, 40, 48, 64)
- Border radii: small 8, medium 12, large 16, xlarge 24
- Cards: white background, `radiusLarge` corners, on `systemGroupedBackground`
- Segmented controls: capsule-shaped with `primaryMint` fill for selected state
- Category icons: circular pastel background + saturated icon (colors from `QuickCategory.colorHex`)

**Home Dashboard Sections:**

1. App bar: month navigation capsule + currency badge
2. Overview: side-by-side income/expense comparison bars with % change badges
3. Report: donut chart (SectorMark) with category breakdown, segmented expense/income picker
4. Trends: 12-month line chart (always from current month, not selected month)

## No Tests

There are no unit or UI tests in the project.
