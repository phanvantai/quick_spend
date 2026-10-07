# QuickSpend: Instant Tracker

A native iOS expense tracking app with voice-powered input and AI categorization.

## Features

- **Voice Input** — Tap to record, speak naturally. AI extracts amount, description, category, and date automatically.
- **AI Parsing** — Powered by Gemini 3.8 Flash via Firebase AI Logic. Understands natural language, slang, and relative dates ("yesterday", "last week").
- **Income & Expense Tracking** — 26 built-in categories across expense and income types, with custom category support.
- **Multiple Wallets** — Keep separate wallets with their own balances; transactions and recurring items belong to a wallet.
- **Recurring Transactions** — Set up daily, weekly, monthly, or yearly recurring items. Auto-generates transactions on app launch.
- **Reports & Insights** — Interactive charts, monthly calendar view with daily totals, spending trends over time.
- **Multi-Language** — English, Vietnamese, Japanese, Spanish (in-app language selection, independent of system locale).
- **Multi-Currency** — USD, VND, JPY, EUR with locale-aware formatting.
- **Dark Mode** — System, light, and dark theme options.
- **iCloud Sync** — Data is stored on device with SwiftData and synced across devices through the user's private iCloud database. Works offline; no separate account required.
- **Freemium** — Free tier with daily AI parse limits; Pro subscription via RevenueCat unlocks unlimited parses, recurring templates, and extended reports.

## Requirements

- iOS 18.0+
- Xcode 26.2+ (required by Firebase iOS SDK 12.x)
- Swift 5.0 language mode

## Getting Started

1. Clone the repository
2. Open `QuickSpend.xcodeproj` in Xcode
3. SPM dependencies resolve automatically (Firebase iOS SDK, RevenueCat)
4. Build and run on simulator or device

### Optional Setup

- **Firebase** — Add your `GoogleService-Info.plist` to enable Analytics and Gemini AI parsing. The app runs without it (voice input falls back to manual entry).
- **RevenueCat** — Subscription management is pre-configured. Without the SDK, all users default to free tier.

## Tech Stack

| Layer | Technology |
| ----- | --------- |
| UI | SwiftUI |
| Data | SwiftData + CloudKit (private database) |
| Preferences | UserDefaults (JSON-encoded AppConfig) |
| AI Parsing | Firebase AI Logic (Gemini 3.8 Flash) |
| Voice | SFSpeechRecognizer + AVAudioEngine |
| Subscriptions | RevenueCat |
| Analytics | Firebase Analytics |
| Localization | Apple String Catalogs (.xcstrings) |

## Project Structure

```bash
QuickSpend/
  Models/          SwiftData models (Transaction, Category, RecurringTemplate,
                   Wallet, BalanceAnchor, BalanceAdjustment), versioned in AppSchema
                   Value types (AppConfig, enums)
  Services/        Business logic (CategoryService, RecurringService, WalletService,
                   BalanceService, CloudSyncService, GeminiParserService,
                   VoiceService, etc.)
  ViewModels/      Observable state (AppConfigViewModel, SubscriptionViewModel)
  Views/
    Components/    Reusable UI (PickerSheet, SettingSelectionRow, etc.)
    Home/          Dashboard with summary, overview, trends, report sections
    Transactions/  Transaction list with calendar grid
    TransactionForm/  Manual add/edit transaction
    Voice/         Voice overlay and editable expense dialog
    Categories/    Category list and form
    Recurring/     Recurring template list and form
    Wallets/       Wallet list and editor (including balance editing)
    Settings/      App settings
    FeatureRequests/  In-app feature request submission
    Splash/        Launch screen while iCloud data loads
    Onboarding/    First-launch flow
    Paywall/       Subscription purchase screen
    Main/          MainTabView, VoiceFABButton
    Report/        Detailed reports
  Theme/           Design system (AppTheme colors/spacing, Color hex extension)
  Utilities/       Constants, formatters, localization helpers
QuickSpendTests/   Unit tests
```

## Architecture

- **No external architecture framework** — Simple SwiftUI + `@Observable` pattern
- **Environment injection** — `AppConfigViewModel` and `SubscriptionViewModel` are created at the app root and passed via `.environment()`
- **SwiftData** manages persistence with a single `ModelContainer` and a versioned schema (`AppSchema`), synced via CloudKit
- **Conditional compilation** — Firebase and RevenueCat features use `#if canImport(...)` guards, so the app builds and runs without these SDKs

## Privacy

- Transaction data is stored on device and synced only to the user's private iCloud database
- No PII logged to analytics (amounts are bucketed, no descriptions sent)
- Privacy policy: <https://portfolio.taiphanvan.dev/quickspend/privacy>

## License

All rights reserved.
