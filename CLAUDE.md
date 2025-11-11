# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Quick Spend is a Flutter expense tracking mobile app with voice input support and bilingual functionality (English/Vietnamese). The app uses **SQLite for local storage** and features **AI-powered expense parsing** using **Gemini 2.5 Flash via Firebase AI**, with automatic categorization and Vietnamese slang support. The app includes comprehensive statistics and reporting with interactive charts.

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
- **AppConfigProvider**: Manages user preferences (language, currency, onboarding status)
- **ExpenseProvider**: Manages expense CRUD operations and state
- **ReportProvider**: Manages statistics calculations and period filtering
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
   - Supports bilingual recognition (en_US, vi_VN)
   - Manages recording state and provides sound level feedback
   - Must be initialized before first use; handles permission requests gracefully

7. **PreferencesService** ([lib/services/preferences_service.dart](lib/services/preferences_service.dart))
   - Wrapper around SharedPreferences
   - Handles app configuration persistence

8. **DatabaseManager** ([lib/services/database_manager.dart](lib/services/database_manager.dart))
   - **Centralized database management for the entire app**
   - Single source of truth for SQLite database instance
   - Manages database initialization, schema creation, and migrations
   - Current schema version: 2
   - Tables: `expenses`, `categories`, `recurring_templates`
   - Handles onCreate for new installations and onUpgrade for existing users
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

### Models

- **Expense** ([lib/models/expense.dart](lib/models/expense.dart)): Core data model with SQLite serialization (NO recurring fields - kept clean)
- **QuickCategory** ([lib/models/category.dart](lib/models/category.dart)): 7 predefined categories with bilingual keywords/labels
- **CategoryStats** ([lib/models/category_stats.dart](lib/models/category_stats.dart)): Statistics for individual expense categories
- **PeriodStats** ([lib/models/period_stats.dart](lib/models/period_stats.dart)): Aggregated statistics for time periods
- **AppConfig** ([lib/models/app_config.dart](lib/models/app_config.dart)): User preference model
- **RecurringExpenseTemplate** ([lib/models/recurring_expense_template.dart](lib/models/recurring_expense_template.dart)): Template configuration for generating recurring expenses (separate from Expense)
- **RecurrencePattern** ([lib/models/recurrence_pattern.dart](lib/models/recurrence_pattern.dart)): Enum for recurrence types (none, monthly, yearly)

### Localization

- Uses `easy_localization` package
- Translation files: [assets/translations/en.json](assets/translations/en.json), [assets/translations/vi.json](assets/translations/vi.json)
- Access translations with `.tr()` extension: `'key.path'.tr()`
- Named arguments supported: `'key'.tr(namedArgs: {'param': value})`

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
- User selects language (en/vi) and currency (USD/VND)
- Settings saved via PreferencesService
- AppConfigProvider manages onboarding state
- Subsequent launches go directly to MainScreen with bottom navigation

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
│   ├── expense_parser.dart     # Main orchestrator (AI + fallback)
│   ├── amount_parser.dart      # Fallback amount extraction (with slang)
│   ├── language_detector.dart  # Fallback language detection
│   ├── categorizer.dart        # Fallback keyword categorization
│   ├── voice_service.dart      # Speech-to-text wrapper
│   ├── database_manager.dart   # Centralized database management
│   ├── expense_service.dart    # Expense & category CRUD operations
│   ├── recurring_template_service.dart # Recurring template CRUD operations
│   ├── recurring_expense_service.dart  # Generates expenses from templates
│   └── preferences_service.dart # SharedPreferences wrapper
├── providers/                   # State management
│   ├── app_config_provider.dart # App configuration state
│   ├── expense_provider.dart   # Expense CRUD state (with recurring generation)
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
│   ├── voice_input_button.dart     # Voice recording FAB
│   └── voice_tutorial_overlay.dart # First-time tutorial
├── theme/                       # Design system
│   └── app_theme.dart          # Theme configuration and constants
└── utils/                       # Utilities
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

7 predefined categories with icons, colors, and bilingual keyword lists:

- Food, Transport, Shopping, Bills, Health, Entertainment, Other
- Categorizer matches keywords in description against category keyword lists
- User can override auto-categorization using `parseWithCategory()`

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
