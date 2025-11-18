# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Quick Spend is a Flutter expense tracking mobile app with voice input support and **multilingual functionality** (English, Vietnamese, Japanese, Korean, Thai, Spanish). The app uses **SQLite for local storage** and features **AI-powered expense parsing** using **Gemini 2.5 Flash via Firebase AI**, with automatic categorization, Vietnamese slang support, and full income/expense tracking. The app includes comprehensive statistics and reporting with interactive charts, calendar view, data import/export capabilities, recurring expenses, daily usage limits, optional opt-in ML training data collection, and **Firebase Analytics** for tracking user behavior and app performance.

## Development Commands

```bash
# Install dependencies
flutter pub get

# Run the app (development)
flutter run

# Run on specific device
flutter run -d <device-id>

# Run tests
flutter test

# Run specific test file
flutter test test/path/to/test_file.dart

# Code analysis
flutter analyze

# Clean build artifacts
flutter clean
```

## Architecture Overview

### State Management

- **Provider**: Primary state management solution
- **AppConfigProvider**: Manages user preferences (language, currency, theme mode, onboarding status, data collection consent)
- **ExpenseProvider**: Manages expense CRUD operations and state
- **CategoryProvider**: Manages category CRUD operations, separates system vs user categories
- **ReportProvider**: Manages statistics calculations and period filtering
- **RecurringTemplateProvider**: Manages recurring expense template CRUD operations
- Provider pattern with `ChangeNotifier` for reactive UI updates

### Core Services Layer

The app uses a hybrid AI + rule-based parsing architecture:

1. **ExpenseParser** ([lib/services/expense_parser.dart](lib/services/expense_parser.dart))
   - Main orchestrator that coordinates parsing operations
   - **NEW**: Now async and returns `List<ParseResult>` (supports multiple expenses from one input)
   - **Primary**: Uses Gemini AI if available (see GeminiExpenseParser below)
   - **Fallback**: Uses rule-based parser if Gemini unavailable or fails
   - Usage: `await ExpenseParser.parse(input, userId)` - returns list of ParseResult
   - Category override: `await ExpenseParser.parseWithCategory(input, userId, category)`

2. **GeminiExpenseParser** ([lib/services/gemini_expense_parser.dart](lib/services/gemini_expense_parser.dart))
   - **AI-powered expense parser using Gemini 2.5 Flash via Firebase AI**
   - **NEW: Enhanced hybrid prompting** - English instructions with language-specific examples
   - **NEW: Date parsing support** - Understands "yesterday", "hôm qua", "last week", "3 days ago", specific dates
   - **NEW: Complex sentence handling** - Handles temporal sequences, multiple items, detailed descriptions
   - **NEW: Incomplete word fixing** - Corrects voice recognition errors ("tiền cơ" → "tiền cơm")
   - **NEW: Input pre-validation** - Filters meaningless voice input to save API costs (empty, too short, filler words like "uh", "um", "ờ", "à")
   - Understands natural language, context, and Vietnamese slang
   - Can extract multiple expenses from one input ("50k coffee and 30k parking")
   - Smart semantic categorization (food, transport, shopping, bills, health, entertainment, other)
   - Returns structured JSON parsed into ParseResult objects
   - **No API key needed** - uses Firebase project authentication automatically
   - **Enhanced Vietnamese slang support**: "ca" (thousand), "củ/cọc" (million), "chai" (hundred)
   - Model: `gemini-2.5-flash` (latest stable with JSON support)
   - Timeout: 30 seconds for first request
   - Check availability: `GeminiExpenseParser.isAvailable`

3. **AmountParser** ([lib/services/amount_parser.dart](lib/services/amount_parser.dart))
   - **Used by fallback parser only** (Gemini handles amounts internally)
   - Extracts and parses amounts from natural language input
   - Supports multiple formats: "50k", "1.5m", "100 nghìn", "1 triệu", "1tr5", formatted numbers
   - **Vietnamese slang support**: "45 ca" = 45,000, "1 củ" = 1,000,000, "2 cọc" = 2,000,000
   - Returns `AmountResult` with parsed amount and remaining description text

4. **LanguageDetector** ([lib/services/language_detector.dart](lib/services/language_detector.dart))
   - **Used by fallback parser only** (Gemini handles language detection)
   - Detects English vs Vietnamese based on diacritics and keywords
   - Returns language code ('en' or 'vi') with confidence score

5. **Categorizer** ([lib/services/categorizer.dart](lib/services/categorizer.dart))
   - **Used by fallback parser only** (Gemini categorizes semantically)
   - Keyword-based expense categorization
   - Language-aware: uses appropriate Vietnamese or English keywords
   - Returns primary category with confidence plus alternative suggestions

6. **VoiceService** ([lib/services/voice_service.dart](lib/services/voice_service.dart))
   - Wraps `speech_to_text` package with permission handling
   - Supports multilingual recognition (en_US, vi_VN, ja_JP, ko_KR, th_TH, es_ES)
   - Manages recording state and provides sound level feedback
   - Must be initialized before first use; handles permission requests gracefully

7. **PreferencesService** ([lib/services/preferences_service.dart](lib/services/preferences_service.dart))
   - Wrapper around SharedPreferences
   - Handles app configuration persistence

8. **DatabaseManager** ([lib/services/database_manager.dart](lib/services/database_manager.dart))
   - **Centralized database management for the entire app**
   - Single source of truth for SQLite database instance
   - Manages database initialization, schema creation, and migrations
   - Current schema version: 3
   - Tables: `expenses`, `categories`, `recurring_templates`
   - Handles onCreate for new installations and onUpgrade for existing users
   - **Recent migration (v2→v3)**: Categories migrated from bilingual (nameEn/nameVi) to single language based on user preference
   - Provides shared database instance to all services
   - **Services depend on DatabaseManager, not on each other**

9. **ExpenseService** ([lib/services/expense_service.dart](lib/services/expense_service.dart))
   - SQLite operations for expense and category persistence
   - Uses shared database from DatabaseManager
   - CRUD operations: create, read, update, delete expenses and categories
   - Efficient querying and filtering by date range, category, type
   - Seeds system categories on first initialization
   - Local-first architecture (no cloud dependency)

10. **RecurringTemplateService** ([lib/services/recurring_template_service.dart](lib/services/recurring_template_service.dart))
   - SQLite operations for recurring expense templates
   - Uses shared database from DatabaseManager
   - CRUD operations: create, read, update, delete templates
   - Toggle template active/inactive status
   - Stores template configurations separately from actual expenses
   - Database table: `recurring_templates` (added in schema v2)

11. **RecurringExpenseService** ([lib/services/recurring_expense_service.dart](lib/services/recurring_expense_service.dart))
   - Generates normal Expense objects from RecurringExpenseTemplate configurations
   - Automatically called on app startup to generate pending expenses
   - Calculates dates based on recurrence pattern (monthly/yearly)
   - Updates lastGeneratedDate to track generation progress
   - Safety limit: max 100 instances per generation cycle
   - Respects template isActive status and endDate

12. **GeminiUsageLimitService** ([lib/services/gemini_usage_limit_service.dart](lib/services/gemini_usage_limit_service.dart))
   - **Daily usage limit tracking for Gemini API calls**
   - Daily limit: 15 parses/day (configurable via AppConstants)
   - Auto-resets daily based on last reset date
   - Shows warning at ≤5 remaining, critical warning at ≤3 remaining
   - Prevents API calls when limit reached (returns specific error, doesn't fallback)
   - Persists count and reset date in SharedPreferences
   - Used by ExpenseParser before calling GeminiExpenseParser

13. **DataCollectionService** ([lib/services/data_collection_service.dart](lib/services/data_collection_service.dart))
   - **Privacy-first opt-in ML training data collection to Firestore**
   - Collects anonymized expense parsing data for improving categorization
   - Tracks: raw input, categories, amounts (NO personal data like descriptions or user IDs)
   - Anonymous UUID-based user IDs (generated per device)
   - Logs expense parsing accuracy and user corrections (gold data)
   - Requires explicit user consent (opt-in)
   - Gracefully handles Firestore not being configured
   - Data used only for ML training to improve parsing accuracy

14. **ExportService** ([lib/services/export_service.dart](lib/services/export_service.dart))
   - **Export expenses and categories to JSON**
   - JSON export: expenses + ALL categories + app settings (version 4.0 format)
   - Export summary statistics (total amount, count, date range)
   - Platform-native share functionality (iOS/Android compatible)
   - Pretty-formatted JSON output for readability
   - Supports full app backup and migration

15. **ImportService** ([lib/services/import_service.dart](lib/services/import_service.dart))
   - **Import expenses and categories from JSON**
   - JSON import: version-aware parsing (v1.0, v2.0, v3.0, v4.0)
   - Duplicate detection by expense ID
   - Category validation with fallback to "Other"
   - Imports app settings (language, currency) from JSON v4.0
   - Full error tracking and reporting
   - Supports data migration and backup restoration

16. **AppConstants** ([lib/utils/constants.dart](lib/utils/constants.dart))
   - **Centralized configuration constants**
   - API Configuration: Gemini timeout (30s), daily limit (15), warning thresholds (5, 3)
   - Voice Input: Min length (2), max length (500), stop delay (100ms)
   - Expense Limits: Max (999,999,999,999), min (0.01), max description (500 chars)
   - Recurring Expenses: Max instances per generation (100), max years ahead (5)
   - Date Validation: Max 10 years past, 1 year future
   - UI/UX: Expenses per page (50), top expenses (5), animation duration (300ms)
   - Database: Version 3, database name
   - Debug: 5 taps to enable debug mode within 3 seconds

17. **AnalyticsService** ([lib/services/analytics_service.dart](lib/services/analytics_service.dart))
   - **Firebase Analytics integration for tracking user behavior and app performance**
   - Singleton pattern for easy access throughout the app
   - Privacy-aware: Never logs PII (amounts, descriptions, personal data)
   - **Screen Tracking**: Automatic screen view logging for all major screens
   - **User Actions**: Expense CRUD operations, voice input events, category management
   - **Feature Usage**: Import/export, recurring templates, report period changes
   - **AI Metrics**: Gemini parse success/failure, fallback parser usage, confidence scores
   - **Settings Changes**: Language, currency, theme mode changes with before/after values
   - **User Properties**: Language, currency, theme, data collection consent
   - Helper methods: `getAmountRange()` for privacy-safe amount bucketing
   - All events logged with debug output for development visibility

### Models

- **Expense** ([lib/models/expense.dart](lib/models/expense.dart)): Core data model with SQLite and Firestore serialization (NO recurring fields - kept clean), supports TransactionType (income/expense)
- **QuickCategory** ([lib/models/category.dart](lib/models/category.dart)): **13 default categories** (7 expense + 6 income) with **multilingual** keywords/labels (en, vi, ja, ko, th, es)
  - **Expense categories**: Food, Transport, Shopping, Bills, Health, Entertainment, Other
  - **Income categories**: Salary, Freelance, Investment, Gift Received, Refund, Other Income
  - Supports both system and user-defined categories with `isSystem` flag
  - Stores icon as codePoint and color as integer for SQLite compatibility
- **CategoryStats** ([lib/models/category_stats.dart](lib/models/category_stats.dart)): Statistics for individual expense categories
- **PeriodStats** ([lib/models/period_stats.dart](lib/models/period_stats.dart)): Aggregated statistics for time periods
- **AppConfig** ([lib/models/app_config.dart](lib/models/app_config.dart)): User preference model with language (6 options), currency (6 options), themeMode (light/dark/system), dataCollectionConsent, and helper methods for currency formatting
- **RecurringExpenseTemplate** ([lib/models/recurring_expense_template.dart](lib/models/recurring_expense_template.dart)): Template configuration for generating recurring expenses (separate from Expense)
- **RecurrencePattern** ([lib/models/recurrence_pattern.dart](lib/models/recurrence_pattern.dart)): Enum for recurrence types (none, monthly, yearly)

### Localization

- Uses `easy_localization` package
- **6 supported languages**: English (en-US), Vietnamese (vi-VN), Japanese (ja-JP), Korean (ko-KR), Thai (th-TH), Spanish (es-ES)
- **6 supported currencies**: USD ($), VND (đ), JPY (¥), KRW (₩), THB (฿), EUR (€)
- Translation files: [assets/translations/](assets/translations/) - en.json, vi.json, ja.json, ko.json, th.json, es.json
- Access translations with `.tr()` extension: `'key.path'.tr()`
- Named arguments supported: `'key'.tr(namedArgs: {'param': value})`
- Category names and keywords fully localized in all 6 languages

### Database Integration

- **sqflite**: Local SQLite database for expense storage
- **path_provider**: Path utilities for database file location
- **Local-first**: All data stored locally, no cloud dependency
- **Future-ready**: Models have serialization ready for potential cloud backup

## Key Implementation Patterns

### Voice Input Flow

1. Long press on FAB to start recording
2. VoiceService requests microphone permission if needed (shows rationale dialog first)
3. Speech-to-text runs with language-specific locale
4. Real-time transcription displayed in overlay
5. Release to stop → text sent to ExpenseParser
6. Swipe up during recording to cancel

### Expense Parsing Flow

```dart
// Input: "50k coffee" or "50k coffee yesterday and 30k parking today"
final results = await ExpenseParser.parse(input, userId);

// Note: Now async and returns List<ParseResult>
// Can return multiple expenses if Gemini detects them
// NEW: Can parse dates from temporal references

for (final result in results) {
  if (result.success && result.expense != null) {
    // result.expense contains:
    // - amount: 50000.0
    // - description: "coffee"
    // - category: ExpenseCategory.food
    // - date: DateTime (parsed from "yesterday", "hôm qua", etc.)
    // - language: "en"
    // - confidence: 0.95 (higher with Gemini)
    // - rawInput: original text
  }
}

// Parsing Strategy:
// 1. Try Gemini AI (if configured) - supports dates, complex sentences, slang
// 2. Fallback to rule-based parser on failure - uses DateTime.now() for date
// 3. Always returns at least one result (success or error)
```

### Onboarding Flow

- First launch shows OnboardingScreen
- User selects language (English, Vietnamese, Japanese, Korean, Thai, Spanish)
- User selects currency (USD, VND, JPY, KRW, THB, EUR)
- Settings saved via PreferencesService
- AppConfigProvider manages onboarding state
- Subsequent launches go directly to MainScreen with bottom navigation
- Categories automatically seeded in selected language

### Navigation Flow

- **MainScreen** serves as the navigation container with bottom navigation bar
- **Home tab**: Expense list with add/edit/delete functionality
- **Report tab**: Statistics dashboard with charts and analytics
- **Global FAB**: Voice input button accessible from all tabs
- Settings accessible from app bar actions

### Recurring Expenses Feature

**Architecture:** Template-based system where recurring configurations are separate from actual expense data.

**Key Components:**
- **RecurringExpenseTemplate**: Configuration model (separate from Expense)
  - Contains: amount, description, category, pattern (monthly/yearly), start/end dates, isActive flag
  - Stored in separate `recurring_templates` SQLite table
  - Never appears in expense list - it's purely configuration

- **RecurringTemplateService**: CRUD operations for templates
  - Manages template storage and retrieval
  - Toggles active/inactive status without deletion

- **RecurringExpenseService**: Generates normal Expense objects
  - Called automatically on app startup (MainScreen initState)
  - Reads active templates, calculates due dates based on pattern
  - Generates normal Expense objects (not templates!) for due dates
  - Updates lastGeneratedDate to avoid duplicates

- **RecurringTemplateProvider**: State management for templates
  - Similar pattern to ExpenseProvider
  - Manages template list and CRUD operations

**User Flow:**
1. User navigates to Settings → Recurring Expenses
2. Add recurring template: amount, description, category, pattern (monthly/yearly), start date, optional end date
3. Template saved with isActive = true
4. Every app startup: RecurringExpenseService checks all active templates
5. For each template: calculates dates since lastGeneratedDate, generates normal expenses
6. Generated expenses appear in Home tab like any manual expense
7. User can pause (isActive = false) or delete templates anytime
8. Paused templates don't generate expenses until reactivated

**Important Design Decision:**
- Expense model has NO recurring fields - kept clean and focused
- Recurring is a separate configuration layer that produces normal expenses
- This separation ensures expenses remain simple transaction records
- Templates are managed in Settings, not in expense add/edit flow

### Import/Export Feature

**Complete data portability system** for backing up and migrating data:

**Export:**
- **JSON Export**: Complete backup (v4.0 format) includes:
  - All expenses with full metadata
  - ALL categories (system + user) with definitions, keywords, icons, colors
  - App settings (language, currency)
  - Export timestamp and summary statistics

**Import:**
- **JSON Import**: Full restoration with version-aware parsing (v1.0-v4.0)
  - Duplicate detection by expense ID
  - Category validation with automatic fallback to "Other"
  - App settings restoration (language, currency)
  - Full error tracking and detailed reporting

**Features:**
- Platform-native share dialogs (iOS/Android)
- Pretty-formatted JSON for human readability
- Summary statistics (total amount, count, date range)
- Accessible from Settings screen

### Data Collection & Privacy

**Optional ML Training Data Collection:**

The app includes a **privacy-first, opt-in system** for collecting anonymized data to improve AI categorization:

**What is collected (if opted in):**
- Raw input text (e.g., "50k coffee")
- Parsed category and amount
- User corrections (gold data for training)
- Anonymous device UUID (NOT linked to personal identity)

**What is NOT collected:**
- Personal descriptions or notes
- User IDs or personal information
- Location data
- Any identifiable information

**Features:**
- Explicit consent required (opt-in dialog after onboarding)
- Data stored in Firestore (gracefully handles if not configured)
- Used exclusively for ML training to improve categorization accuracy
- Can be disabled anytime in Settings

### Gemini Usage Limits

**Daily API limit tracking** to manage costs and prevent abuse:

- **Daily limit**: 15 Gemini API calls per day (configurable via AppConstants)
- **Auto-reset**: Resets daily based on last reset date
- **UI warnings**:
  - Warning banner when ≤5 parses remaining
  - Critical warning when ≤3 parses remaining
- **Limit reached**: Returns specific error (does NOT fallback to rule-based parser)
- **Persistence**: Count and reset date saved in SharedPreferences
- **User visibility**: Remaining count shown in MainScreen banner

## Project Structure

```bash
lib/
├── main.dart                    # App entry point with EasyLocalization setup
├── firebase_options.dart        # Firebase AI configuration
├── models/                      # Data models
│   ├── expense.dart            # Expense with SQLite serialization (NO recurring fields)
│   ├── category.dart           # Categories with bilingual support
│   ├── category_stats.dart     # Category statistics model
│   ├── period_stats.dart       # Period statistics model
│   ├── app_config.dart         # User preferences model
│   ├── recurring_expense_template.dart # Recurring template configuration (separate from Expense)
│   └── recurrence_pattern.dart # Recurrence pattern enum (monthly/yearly)
├── services/                    # Business logic layer
│   ├── gemini_expense_parser.dart # AI parser (Gemini 2.5 Flash via Firebase)
│   ├── gemini_usage_limit_service.dart # Daily Gemini usage limit tracking (15/day)
│   ├── expense_parser.dart     # Main orchestrator (AI + fallback)
│   ├── amount_parser.dart      # Fallback amount extraction (with slang)
│   ├── language_detector.dart  # Fallback language detection
│   ├── categorizer.dart        # Fallback keyword categorization
│   ├── voice_service.dart      # Speech-to-text wrapper
│   ├── database_manager.dart   # Centralized database management
│   ├── expense_service.dart    # Expense & category CRUD operations
│   ├── recurring_template_service.dart # Recurring template CRUD operations
│   ├── recurring_expense_service.dart  # Generates expenses from templates
│   ├── data_collection_service.dart # Opt-in ML training data collection
│   ├── export_service.dart     # Export to JSON
│   ├── import_service.dart     # Import from JSON
│   └── preferences_service.dart # SharedPreferences wrapper
├── providers/                   # State management
│   ├── app_config_provider.dart # App configuration state
│   ├── expense_provider.dart   # Expense CRUD state (with recurring generation)
│   ├── category_provider.dart  # Category CRUD state (system + user categories)
│   ├── report_provider.dart    # Statistics and reports state
│   └── recurring_template_provider.dart # Recurring template state
├── screens/                     # UI screens
│   ├── onboarding_screen.dart  # Language/currency selection
│   ├── main_screen.dart        # Main container with bottom navigation
│   ├── home_screen.dart        # Expense list tab
│   ├── expense_form_screen.dart # Add/edit expense manually (full screen)
│   ├── all_expenses_screen.dart # View all expenses list
│   ├── report_screen.dart      # Statistics and charts tab
│   ├── settings_screen.dart    # App settings
│   ├── categories_screen.dart  # Manage categories
│   ├── category_form_screen.dart # Add/edit category form
│   ├── recurring_expenses_screen.dart # Recurring templates management
│   └── recurring_expense_form_screen.dart # Add/edit recurring template form
├── widgets/                     # Reusable UI components
│   ├── common/                 # Common widgets
│   │   ├── expense_card.dart   # Swipeable expense card
│   │   ├── category_chip.dart  # Category badge
│   │   ├── empty_state.dart    # Empty list placeholder
│   │   ├── gradient_button.dart # Custom button
│   │   └── stat_card.dart      # Statistics card
│   ├── home/                   # Home screen widgets
│   │   ├── home_summary_card.dart # Home summary widget
│   │   └── editable_expense_dialog.dart # Voice parsing confirmation dialog
│   ├── report/                 # Report-specific widgets
│   │   ├── category_donut_chart.dart # Category breakdown chart
│   │   ├── spending_trend_chart.dart # Spending trend line chart
│   │   ├── category_list.dart        # Category statistics list
│   │   ├── category_breakdown_switcher.dart # Category breakdown view switcher
│   │   ├── top_expenses_list.dart    # Top expenses widget
│   │   ├── summary_card.dart         # Summary statistics
│   │   ├── stats_grid.dart           # Statistics grid
│   │   ├── period_filter.dart        # Period selector chips
│   │   └── custom_date_range_picker.dart # Date range picker
│   ├── recurring/              # Recurring expense widgets
│   │   └── recurring_template_card.dart # Template display card
│   ├── calendar/               # Calendar view widgets
│   │   ├── calendar_grid.dart        # Monthly calendar view with daily totals
│   │   ├── date_section_header.dart  # Date section headers
│   │   ├── month_navigator.dart      # Month navigation controls
│   │   └── monthly_summary_card.dart # Monthly summary statistics
│   ├── voice_input_button.dart     # Voice recording FAB
│   └── voice_tutorial_overlay.dart # First-time tutorial
├── theme/                       # Design system
│   └── app_theme.dart          # Theme configuration and constants
└── utils/                       # Utilities
    ├── constants.dart          # App-wide configuration constants
    └── date_range_helper.dart  # Date range calculations
```

## Configuration

### Firebase AI Setup

The app uses **Firebase AI with Gemini 2.5 Flash** for intelligent expense parsing:

1. **Firebase Project**: `gen-lang-client-0627362600`
2. **Firebase Options**: Auto-generated in [lib/firebase_options.dart](lib/firebase_options.dart)
3. **Model**: `gemini-2.5-flash` (latest stable model)
4. **Authentication**: Uses Firebase project config - **no API key needed in code**
5. **Fallback**: Automatically uses rule-based parser if AI fails or times out

**How it works**:

- Firebase is initialized in [lib/main.dart](lib/main.dart) with `Firebase.initializeApp()`
- GeminiExpenseParser uses `FirebaseAI.googleAI().generativeModel()`
- No API keys stored in code - Firebase handles authentication

**Package**: `firebase_ai: ^3.4.0` (official Google SDK for Gemini)

## Technical Notes

### Debugging Voice Recognition

The VoiceService includes extensive debug logging with emoji prefixes:

- 🎙️ Initialization
- 🔐 Permissions
- 🎧 Listening state
- 📝 Recognition results
- Use Flutter DevTools console to monitor voice input flow

### Confidence Scores

ExpenseParser provides multi-level confidence:

- **Gemini parser**: Typically 0.90-0.95 confidence (very accurate)
- **Rule-based parser**: Weighted average (50% categorization, 30% language, 20% amount)
- Individual confidences available for each parsing step
- UI can warn users when confidence < 0.7

### Multiple Expense Support

Gemini can extract multiple expenses from one input:

- Input: "50k coffee and 30k parking"
- Output: 2 separate expenses with different categories
- UI shows all expenses in a scrollable dialog
- Rule-based parser only extracts first expense

### Vietnamese Slang Support

Both AI and fallback parsers understand Vietnamese money slang:

- **"ca"** = thousand (k) — "45 ca tiền cơm" = 45,000 VND
- **"củ"** = million — "1 củ xăng" = 1,000,000 VND
- **"cọc"** = million — "2 cọc" = 2,000,000 VND
- **"chai"** = hundred — "5 chai" = 500 VND (less common)

**NEW: Enhanced Gemini support** for incomplete words from voice recognition:
- "tiền cơ" → "tiền cơm" (meal money)
- "xă" → "xăng" (gasoline)
- "cafe" → "cà phê" (coffee)

This makes voice input more natural and accurate for Vietnamese users.

### Input Pre-Validation

**NEW**: GeminiExpenseParser includes input validation to avoid meaningless API calls:

**Filters out:**
- Empty or whitespace-only input
- Too short input (< 2 characters)
- No alphanumeric characters
- Common filler words: "uh", "um", "ah", "er", "hmm" (English) and "ờ", "à", "ư", "ừ", "ơ" (Vietnamese)
- Repeated single characters: "a a a", "uh uh uh"
- Suspicious repetition: same word repeated 3+ times
- Just punctuation or symbols

**Benefits:**
- Saves API costs by avoiding unnecessary Gemini calls
- Improves performance by failing fast on invalid input
- Better user experience with immediate feedback on nonsensical input

**Note**: The validator allows input without numbers (e.g., "coffee today") as it might still be valid, letting Gemini determine if it's parseable.

### Categories

**13 default system categories** with icons, colors, and multilingual keyword lists:

**Expense Categories (7):**
- Food, Transport, Shopping, Bills, Health, Entertainment, Other

**Income Categories (6):**
- Salary, Freelance, Investment, Gift Received, Refund, Other Income

**Features:**
- Each category has localized names and keywords in all 6 languages (en, vi, ja, ko, th, es)
- System categories cannot be deleted (isSystem flag)
- Users can create custom categories with custom icons, colors, and keywords
- Categorizer matches keywords in description against category keyword lists
- User can override auto-categorization using `parseWithCategory()`
- Categories support both income and expense types (TransactionType enum)

### Design System & Theming

**[lib/theme/app_theme.dart](lib/theme/app_theme.dart)**

The app uses a comprehensive design system:

- **Material Design 3**: Full MD3 compliance with custom theme
- **Color Palette**: Mint green gradient theme with vibrant accents
  - Primary: Mint green (#00D9A3) to Green (#00C896)
  - Accents: Pink (#FF6B9D), Orange (#FF8C42), Teal (#00D9C0)
  - Neutrals: 10-level grayscale from #1A1A2E to #FBFBFD
  - Semantic: Success, Warning, Error, Info colors
  - Category colors: Unique color for each expense category
- **Spacing System**: Consistent 4px-based spacing (4, 8, 12, 16, 20, 24, 32, 40, 48)
- **Typography**: Material Design 3 type scale with custom weights
- **Gradients**: Primary gradient (mint to green), accent gradient (pink to orange)
- **Light & Dark Mode**: Complete theme support for both modes

**[DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)**

Comprehensive design documentation including:

- Complete color palette with hex codes
- Typography scale and usage guidelines
- Component patterns and best practices
- Spacing and layout system
- Accessibility guidelines

### UI Components

**Common Widgets** ([lib/widgets/common/](lib/widgets/common/)):

- **ExpenseCard**: Swipeable card with edit/delete actions (uses flutter_slidable)
- **CategoryChip**: Color-coded category badge
- **EmptyState**: Friendly empty list placeholder with icon and message
- **GradientButton**: Custom button with gradient background
- **StatCard**: Statistics display card

**Report Widgets** ([lib/widgets/report/](lib/widgets/report/)):

- **CategoryDonutChart**: Interactive donut chart with category breakdown (fl_chart)
- **SpendingTrendChart**: Line chart showing spending over time (fl_chart)
- **CategoryList**: List view of category statistics with percentages
- **TopExpensesList**: Widget showing largest expenses
- **SummaryCard**: Overall statistics summary
- **StatsGrid**: Grid of key metrics (average, highest, trend)
- **PeriodFilter**: Chip-based period selector (Today/Week/Month/Year/Custom)
- **CustomDateRangePicker**: Calendar-based custom date range picker

**Calendar Widgets** ([lib/widgets/calendar/](lib/widgets/calendar/)):

- **CalendarGrid**: Monthly calendar view with daily income/expense totals
- **MonthNavigator**: Month navigation controls (previous/next)
- **MonthlySummaryCard**: Monthly summary statistics card
- **DateSectionHeader**: Date section headers for expense lists

### Statistics & Reporting

**[lib/providers/report_provider.dart](lib/providers/report_provider.dart)**

The ReportProvider manages all statistics calculations:

- Period-based filtering (today, this week, this month, this year, custom range)
- Category aggregations with percentages
- Spending trends over time
- Top expenses tracking
- Average daily spending
- Comparison with previous periods
- Real-time updates when expenses change

**Period Options:**

- **Today**: Current day's expenses
- **Week**: Last 7 days
- **Month**: Last 30 days
- **Year**: Last 365 days
- **Custom**: User-selected date range

### Database Operations

**[lib/services/expense_service.dart](lib/services/expense_service.dart)**

SQLite operations with sqflite:

```dart
// Create expense
await expenseService.addExpense(expense);

// Read expenses (all or filtered)
final expenses = await expenseService.getExpenses();
final filtered = await expenseService.getExpensesByDateRange(startDate, endDate);

// Update expense
await expenseService.updateExpense(expense);

// Delete expense
await expenseService.deleteExpense(expenseId);
```

Database schema:

- id (TEXT PRIMARY KEY)
- amount (REAL)
- description (TEXT)
- category (TEXT)
- language (TEXT)
- date (TEXT - ISO 8601)
- userId (TEXT)
- rawInput (TEXT)
- confidence (REAL)
