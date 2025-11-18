# Quick Spend - Expense Tracker

A Flutter mobile app for quickly logging expenses and income with voice input and automatic categorization. Supports 6 languages (English, Vietnamese, Japanese, Korean, Thai, Spanish) and 6 currencies.

## Features

### Voice & AI
- 🎤 **Voice Input**: Speak your expenses naturally in 6 languages (en, vi, ja, ko, th, es)
- 🤖 **AI-Powered Parsing**: Uses Gemini 2.5 Flash via Firebase AI for intelligent expense extraction
- 💬 **Vietnamese Slang Support**: Understands "ca" (thousand), "củ/cọc" (million), incomplete words
- ✨ **Multiple Expenses**: Parse several expenses from one input ("50k coffee and 30k parking")
- 📅 **Date Parsing**: Understands "yesterday", "hôm qua", "last week", "3 days ago"
- 💰 **Flexible Input Formats**:
  - "50k coffee" → 50,000 VND
  - "1.5m shopping" → 1,500,000 VND
  - "100 nghìn xăng" → 100,000 VND
  - "45 ca tiền cơm" → 45,000 VND (Vietnamese slang!)
  - "1 củ xăng" → 1,000,000 VND (Vietnamese slang!)
- 🔄 **Hybrid Architecture**: Gemini AI primary + rule-based fallback for reliability
- ⏱️ **Daily Limits**: 15 Gemini parses/day with UI warnings (cost management)

### Multilingual & Categories
- 🌍 **6 Languages**: English, Vietnamese, Japanese, Korean, Thai, Spanish
- 💵 **6 Currencies**: USD, VND, JPY, KRW, THB, EUR
- 📂 **13 Default Categories**: 7 expense + 6 income categories, fully localized
- ➕ **Custom Categories**: Create your own categories with custom icons, colors, keywords
- 📊 **Smart Categorization**: AI categorizes based on context and keywords

### Income & Expense Tracking
- 💰 **Income Support**: Track both income and expenses with dedicated categories
- 🏷️ **Transaction Types**: Automatic income/expense detection
- 💚💸 **Color Coding**: Green for income, red/neutral for expenses
- 🧮 **Net Balance**: Automatic calculation of income - expenses

### Recurring & Automation
- 🔁 **Recurring Expenses**: Set up monthly/yearly recurring transactions (rent, salary, subscriptions)
- 🤖 **Auto-Generation**: Automatically generates recurring expenses on app startup
- ⏸️ **Pause/Resume**: Toggle recurring templates without deletion

### Reports & Analytics
- 📈 **Statistics Dashboard**: Visual insights with charts and analytics
- 📊 **Multiple Charts**: Donut chart, trend chart, category breakdown, top expenses
- 📅 **Calendar View**: Monthly calendar with daily income/expense totals
- 🎯 **Period Filtering**: Today, Week, Month, Year, or Custom date range
- 📉 **Trend Analysis**: Compare current vs previous period

### Data Management
- 📤 **Export Data**: CSV (expenses only) or JSON (full backup with categories & settings)
- 📥 **Import Data**: Restore from CSV/JSON with duplicate detection and validation
- 💾 **SQLite Storage**: Local-first architecture, all data stored on device
- 🔄 **Version Aware**: Supports JSON import from v1.0-v4.0 formats

### UI & UX
- 📱 **Bottom Navigation**: Seamless navigation between Home and Report tabs
- ✏️ **Swipeable Cards**: Edit or delete expenses with gestures
- 🎨 **Dark Mode**: Complete light/dark theme support
- 🎓 **Interactive Tutorial**: First-time voice input tutorial with animations
- 🗑️ **Batch Operations**: Manage categories and recurring templates efficiently

### Privacy & Transparency
- 🔒 **Privacy-First**: All data stored locally, no cloud dependency
- 🎯 **Opt-in Data Collection**: Optional anonymized ML training data (explicit consent required)
- 🚫 **No Personal Data**: Never collects descriptions, user IDs, or identifiable info

## Tech Stack

- **Flutter** (latest stable)
- **SQLite** (sqflite - Local database)
- **Firebase AI** (Gemini 2.5 Flash for expense parsing)
- **Provider** (State management)
- **easy_localization** (i18n/l10n)
- **speech_to_text** (Voice input)
- **fl_chart** (Charts and graphs)
- **flutter_slidable** (Swipeable cards)
- **shared_preferences** (User preferences)
- **permission_handler** (Microphone permissions)

## Project Structure

```bash
lib/
├── models/           # Data models
│   ├── expense.dart         # Expense model with SQLite/Firestore integration
│   ├── category.dart        # QuickCategory with multilingual support (13 default)
│   ├── category_stats.dart  # Statistics for expense categories
│   ├── period_stats.dart    # Statistics for time periods
│   ├── app_config.dart      # App config (6 languages, 6 currencies, theme, consent)
│   ├── recurring_expense_template.dart # Recurring expense templates
│   └── recurrence_pattern.dart        # Recurrence pattern enum
├── services/         # Business logic
│   ├── gemini_expense_parser.dart # AI-powered parser (Gemini 2.5 Flash)
│   ├── gemini_usage_limit_service.dart # Daily usage limit tracking (15/day)
│   ├── expense_parser.dart        # Main parser orchestrator (AI + fallback)
│   ├── amount_parser.dart         # Fallback amount parser (with slang support)
│   ├── language_detector.dart     # Fallback language detection
│   ├── categorizer.dart           # Fallback keyword categorization
│   ├── voice_service.dart         # Speech-to-text wrapper (6 languages)
│   ├── database_manager.dart      # Centralized database management (schema v3)
│   ├── expense_service.dart       # Expense & category CRUD operations
│   ├── recurring_template_service.dart # Recurring template CRUD operations
│   ├── recurring_expense_service.dart  # Generate expenses from templates
│   ├── data_collection_service.dart # Opt-in ML training data collection
│   ├── export_service.dart        # Export to CSV/JSON
│   ├── import_service.dart        # Import from CSV/JSON
│   └── preferences_service.dart   # SharedPreferences wrapper
├── providers/        # State management
│   ├── app_config_provider.dart # App configuration state
│   ├── expense_provider.dart    # Expense management state
│   ├── category_provider.dart   # Category management state (system + user)
│   ├── report_provider.dart     # Statistics and reports state
│   └── recurring_template_provider.dart # Recurring template state
├── screens/          # UI screens
│   ├── onboarding_screen.dart # Language/currency selection
│   ├── main_screen.dart       # Main screen with bottom navigation
│   ├── home_screen.dart       # Expense list and input
│   ├── expense_form_screen.dart # Add/edit expense manually
│   ├── all_expenses_screen.dart # View all expenses
│   ├── report_screen.dart     # Statistics and charts
│   ├── settings_screen.dart   # App settings
│   ├── categories_screen.dart # Manage categories
│   ├── category_form_screen.dart # Add/edit category
│   ├── recurring_expenses_screen.dart # Manage recurring expenses
│   └── recurring_expense_form_screen.dart # Add/edit recurring template
├── widgets/          # Reusable widgets
│   ├── common/                    # Common UI components
│   │   ├── expense_card.dart      # Expense list item
│   │   ├── category_chip.dart     # Category badge
│   │   ├── empty_state.dart       # Empty list placeholder
│   │   ├── gradient_button.dart   # Custom button
│   │   └── stat_card.dart         # Statistics card
│   ├── home/                      # Home screen widgets
│   │   ├── home_summary_card.dart # Home summary widget
│   │   └── editable_expense_dialog.dart # Voice parsing confirmation
│   ├── report/                    # Report-specific widgets
│   │   ├── category_donut_chart.dart    # Category breakdown chart
│   │   ├── spending_trend_chart.dart    # Spending over time chart
│   │   ├── category_list.dart           # Category statistics list
│   │   ├── category_breakdown_switcher.dart # Category view switcher
│   │   ├── top_expenses_list.dart       # Largest expenses list
│   │   ├── summary_card.dart            # Summary statistics
│   │   ├── stats_grid.dart              # Statistics grid
│   │   ├── period_filter.dart           # Date range selector
│   │   └── custom_date_range_picker.dart # Custom date picker
│   ├── recurring/                 # Recurring expense widgets
│   │   └── recurring_template_card.dart # Recurring template card
│   ├── calendar/                  # Calendar view widgets
│   │   ├── calendar_grid.dart        # Monthly calendar with daily totals
│   │   ├── month_navigator.dart      # Month navigation controls
│   │   ├── monthly_summary_card.dart # Monthly summary statistics
│   │   └── date_section_header.dart  # Date section headers
│   ├── voice_input_button.dart    # Voice recording FAB
│   └── voice_tutorial_overlay.dart # Voice input tutorial
├── theme/            # Design system
│   └── app_theme.dart # Theme configuration and constants
└── utils/            # Utilities
    ├── constants.dart          # App-wide configuration constants
    └── date_range_helper.dart  # Date range calculations

assets/
└── translations/     # Localization files (6 languages)
    ├── en.json       # English
    ├── vi.json       # Vietnamese
    ├── ja.json       # Japanese
    ├── ko.json       # Korean
    ├── th.json       # Thai
    └── es.json       # Spanish
```

## Phase 1 ✅ Complete

### Models Created

#### Expense Model ([lib/models/expense.dart](lib/models/expense.dart))

- Complete expense data structure
- Firestore serialization/deserialization
- Formatted amount display (VND/USD)
- Immutable with `copyWith` support

#### QuickCategory Model ([lib/models/category.dart](lib/models/category.dart))

- **13 default categories**: 7 expense + 6 income categories
  - **Expense**: Food, Transport, Shopping, Bills, Health, Entertainment, Other
  - **Income**: Salary, Freelance, Investment, Gift Received, Refund, Other Income
- **Multilingual**: Labels and keywords in all 6 languages (en, vi, ja, ko, th, es)
- Material icons and colors for each category
- System categories (isSystem flag) cannot be deleted
- Users can create custom categories
- Comprehensive keyword lists for auto-categorization

### Services Created

#### Amount Parser ([lib/services/amount_parser.dart](lib/services/amount_parser.dart))

Handles various amount formats:

- Vietnamese: "50 nghìn", "1 triệu", "1tr5"
- Short form: "50k", "1.5m"
- Formatted: "100,000"
- Plain numbers: "50000"

#### Language Detector ([lib/services/language_detector.dart](lib/services/language_detector.dart))

- Detects Vietnamese by diacritics (à, á, ả, ã, ạ, etc.)
- Checks Vietnamese keywords
- Returns confidence score
- Defaults to English when ambiguous

#### Categorizer ([lib/services/categorizer.dart](lib/services/categorizer.dart))

- Keyword-based matching
- Language-aware (uses appropriate keyword list)
- Returns confidence score (0-1)
- Provides alternative category suggestions

#### Expense Parser ([lib/services/expense_parser.dart](lib/services/expense_parser.dart))

Main orchestrator that:

1. Detects language
2. Extracts amount
3. Cleans description
4. Auto-categorizes
5. Returns structured Expense with confidence scores

## Usage Examples

```dart
import 'package:quick_spend/services/expense_parser.dart';

// Parse English input
final result1 = ExpenseParser.parse("50k coffee", "user123");
// Result: $50,000, "coffee", Category: Food, Language: en

// Parse Vietnamese input
final result2 = ExpenseParser.parse("100k xăng", "user123");
// Result: 100,000 VND, "xăng", Category: Transport, Language: vi

// Parse with Vietnamese words
final result3 = ExpenseParser.parse("1 triệu 5 mua sắm", "user123");
// Result: 1,500,000 VND, "mua sắm", Category: Shopping, Language: vi

// Override category
final result4 = ExpenseParser.parseWithCategory(
  "50k misc item",
  "user123",
  ExpenseCategory.other,
);
```

## Testing the Parser

You can test the core parsing functionality:

```dart
void main() {
  // Test amount parsing
  final amount1 = AmountParser.parseAmount("50k");
  print(amount1); // 50000.0

  final amount2 = AmountParser.parseAmount("1.5m");
  print(amount2); // 1500000.0

  // Test language detection
  final lang1 = LanguageDetector.detectLanguage("coffee");
  print(lang1); // en

  final lang2 = LanguageDetector.detectLanguage("cà phê");
  print(lang2); // vi

  // Test full parsing
  final result = ExpenseParser.parse("50k coffee", "user123");
  if (result.success) {
    print(result.expense);
    print("Confidence: ${result.overallConfidence}");
  }
}
```

## Phase 2 ✅ Complete - Onboarding & Localization

### Onboarding Flow

**[lib/screens/onboarding_screen.dart](lib/screens/onboarding_screen.dart)**

- Beautiful Material Design 3 UI
- **Language selection**: English 🇺🇸, Tiếng Việt 🇻🇳, 日本語 🇯🇵, 한국어 🇰🇷, ไทย 🇹🇭, Español 🇪🇸
- **Currency selection**: USD $, VND đ, JPY ¥, KRW ₩, THB ฿, EUR €
- Smooth navigation to home screen
- Preferences saved automatically
- Categories automatically seeded in selected language

### Localization System

**[assets/translations/](assets/translations/)**

- Complete i18n setup with `easy_localization`
- JSON translation files for **6 languages** (en, vi, ja, ko, th, es)
- Dynamic locale switching based on user preference
- Supports named arguments (e.g., `{currency}`)

**Key Features:**

- All UI text is localized in 6 languages
- Language changes take effect immediately
- Fallback to English if translation missing
- Category names and keywords fully localized

### App Configuration

**[lib/models/app_config.dart](lib/models/app_config.dart)**

- User preferences model (language, currency, theme mode, data collection consent)
- **6 language options** with localized display names
- **6 currency options** with smart formatting (symbol placement, decimals)
- **Theme mode**: Light, Dark, System
- **Data collection consent**: Opt-in for ML training
- JSON serialization for persistence
- Helper methods for currency formatting

**[lib/services/preferences_service.dart](lib/services/preferences_service.dart)**

- SharedPreferences wrapper
- Save/load configuration
- Onboarding completion tracking

**[lib/providers/app_config_provider.dart](lib/providers/app_config_provider.dart)**

- State management with Provider
- Real-time config updates
- Automatic persistence

### How It Works

1. **First Launch:** Shows onboarding screen
2. **User Selects:** Language and currency preferences
3. **Tap "Get Started":** Saves preferences and navigates to home
4. **Subsequent Launches:** Shows home screen directly
5. **Locale Switching:** Updates immediately throughout the app

### Adding New Translations

1. Add keys to `assets/translations/en.json` and `assets/translations/vi.json`
2. Use in code: `'key.path'.tr()` or `'key.path'.tr(namedArgs: {'param': value})`
3. Hot reload to see changes

Example:

```json
// en.json
{
  "welcome": {
    "title": "Welcome to {appName}",
    "message": "Start tracking today"
  }
}

// vi.json
{
  "welcome": {
    "title": "Chào mừng đến {appName}",
    "message": "Bắt đầu theo dõi hôm nay"
  }
}
```

```dart
// In code
Text('welcome.title'.tr(namedArgs: {'appName': 'Quick Spend'}))
Text('welcome.message'.tr())
```

## Phase 3 ✅ Complete - Database & Voice Input

### Local Database (SQLite)

**[lib/services/expense_service.dart](lib/services/expense_service.dart)**

- SQLite database with sqflite
- CRUD operations for expenses
- Efficient querying and filtering
- Local-first architecture (no cloud dependency)

**[lib/providers/expense_provider.dart](lib/providers/expense_provider.dart)**

- State management for expenses
- Real-time UI updates
- Expense creation, editing, deletion
- Automatic persistence

### Voice Service

**[lib/services/voice_service.dart](lib/services/voice_service.dart)**

- Speech-to-text integration
- Bilingual recognition (English/Vietnamese)
- Microphone permission handling
- Sound level feedback
- Real-time transcription

**[lib/widgets/voice_input_button.dart](lib/widgets/voice_input_button.dart)**

- Global floating action button
- Long-press to record, release to send
- Swipe up to cancel recording
- Visual feedback with animations
- Tutorial overlay for first-time users

## Phase 4 ✅ Complete - Main UI & Navigation

### Main Screen & Navigation

**[lib/screens/main_screen.dart](lib/screens/main_screen.dart)**

- Bottom navigation bar (Home, Report)
- Global voice input button available on all tabs
- Smooth transitions between screens
- Persistent state management

### Home Screen

**[lib/screens/home_screen.dart](lib/screens/home_screen.dart)**

- Expense list with swipeable cards
- Edit and delete functionality
- Empty state with helpful message
- Real-time expense updates

**[lib/widgets/common/expense_card.dart](lib/widgets/common/expense_card.dart)**

- Beautiful card design
- Swipe to edit or delete (flutter_slidable)
- Category icons and colors
- Formatted amounts with currency

**[lib/widgets/edit_expense_dialog.dart](lib/widgets/edit_expense_dialog.dart)**

- Edit expense amount, description, category
- Date picker for expense date
- Form validation
- Smooth modal animations

## Phase 5 ✅ Complete - Statistics & Reports

### Report Screen

**[lib/screens/report_screen.dart](lib/screens/report_screen.dart)**

- Comprehensive statistics dashboard
- Multiple visualization types
- Period filtering (Today, Week, Month, Year, Custom)
- Real-time data updates

**[lib/providers/report_provider.dart](lib/providers/report_provider.dart)**

- Statistics calculations
- Period-based filtering
- Category aggregations
- Top expenses tracking

### Report Widgets

**Charts:**

- **[category_donut_chart.dart](lib/widgets/report/category_donut_chart.dart)**: Interactive donut chart showing spending by category
- **[spending_trend_chart.dart](lib/widgets/report/spending_trend_chart.dart)**: Line chart showing spending over time

**Lists & Statistics:**

- **[summary_card.dart](lib/widgets/report/summary_card.dart)**: Total spending and expense count
- **[stats_grid.dart](lib/widgets/report/stats_grid.dart)**: Key metrics (average, highest, trend)
- **[category_list.dart](lib/widgets/report/category_list.dart)**: Breakdown by category with percentages
- **[top_expenses_list.dart](lib/widgets/report/top_expenses_list.dart)**: Largest individual expenses

**Filters:**

- **[period_filter.dart](lib/widgets/report/period_filter.dart)**: Quick period selection chips
- **[custom_date_range_picker.dart](lib/widgets/report/custom_date_range_picker.dart)**: Custom date range selector

## Phase 6 ✅ Complete - Settings & Design System

### Settings Screen

**[lib/screens/settings_screen.dart](lib/screens/settings_screen.dart)**

- **Language selection**: 6 languages (en, vi, ja, ko, th, es)
- **Currency selection**: 6 currencies (USD, VND, JPY, KRW, THB, EUR)
- **Theme selection**: Light, Dark, System
- **Import/Export**: CSV or JSON with full backup/restore
- **Recurring Expenses**: Manage recurring templates
- **Custom Categories**: Add/edit user categories
- **Data Collection**: Opt-in/out for ML training
- App information and version
- Clean, organized UI with sections

### Design System

**[lib/theme/app_theme.dart](lib/theme/app_theme.dart)**

- Complete Material Design 3 theme
- Mint green gradient color scheme
- Consistent spacing system (4px, 8px, 12px, 16px, etc.)
- Semantic colors (success, warning, error, info)
- Category colors for visual categorization
- Light and dark mode support
- Typography scale

**[DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)**

- Comprehensive design documentation
- Color palette with hex codes
- Typography guidelines
- Component usage patterns
- Spacing and layout system

## Phase 7 ✅ Complete - Recurring Expenses

### Recurring Expenses Feature

**Template-based system** for managing recurring expenses:

- Set up monthly or yearly recurring expenses (rent, subscriptions, bills, etc.)
- Templates stored separately from actual expenses
- Automatic generation on app startup
- Active/inactive toggle without deletion
- Optional end date for limited-time recurring expenses
- Generated expenses appear as normal expenses in the home screen

**Key Components:**

- **RecurringExpenseTemplate**: Configuration model (amount, description, category, pattern, dates)
- **RecurringTemplateService**: CRUD operations for templates
- **RecurringExpenseService**: Generates normal Expense objects from templates
- **RecurringTemplateProvider**: State management for templates

**Screens:**

- **recurring_expenses_screen.dart**: Manage recurring expense templates
- **recurring_expense_form_screen.dart**: Add/edit recurring templates

## Phase 8 ✅ Complete - Import/Export & Data Collection

### Import/Export Feature

**Complete data portability:**

- **CSV Export**: Expenses only for spreadsheet analysis
- **JSON Export**: Full backup (v4.0) with expenses, categories, and settings
- **CSV Import**: Import expenses with validation
- **JSON Import**: Full restoration with version-aware parsing (v1.0-v4.0)
- **Features**: Duplicate detection, category validation, error tracking, platform-native share

### Data Collection

**Privacy-first ML training data collection:**

- **Opt-in only**: Explicit consent required
- **Anonymized**: No personal data, descriptions, or identifiable info
- **Purpose**: Improve AI categorization accuracy
- **Control**: Can be disabled anytime in Settings
- **Transparency**: Clear about what is and isn't collected

## Phase 9 ✅ Complete - Multilingual Expansion

### 6 Languages & Currencies

- **Languages**: English, Vietnamese, Japanese, Korean, Thai, Spanish
- **Currencies**: USD, VND, JPY, KRW, THB, EUR
- **Categories**: All 13 categories fully localized with keywords
- **UI**: Complete translation of all screens and messages
- **Smart Formatting**: Currency symbol placement and decimal handling per locale

## Phase 10 ✅ Complete - Income Tracking & Calendar View

### Income Support

- **6 income categories**: Salary, Freelance, Investment, Gift Received, Refund, Other Income
- **Transaction types**: Automatic income/expense detection
- **Net balance**: Income - expenses calculation
- **Color coding**: Green for income, red/neutral for expenses

### Calendar View

- **Monthly calendar**: Grid view with daily income/expense totals
- **Month navigation**: Previous/next month controls
- **Summary card**: Monthly statistics
- **Visual indicators**: Color-coded daily amounts

## Next Steps (Future Enhancements)

### Potential Features

- [ ] Search and filter expenses by keyword, amount range
- [ ] Expense tags and notes
- [ ] Budget tracking and alerts
- [ ] PDF export with charts and summaries
- [ ] Multiple currency support in single session (multi-currency expenses)
- [ ] Cloud backup and sync (Firebase Firestore)
- [ ] Expense attachments (receipts/photos via camera or gallery)
- [ ] Split expenses with others (expense sharing)
- [ ] Notifications for recurring expenses and budgets
- [ ] Widgets for quick expense entry
- [ ] Biometric authentication for app access

## Development

```bash
# Get dependencies
flutter pub get

# Run the app
flutter run

# Run tests
flutter test

# Analyze code
flutter analyze
```

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase for Flutter](https://firebase.google.com/docs/flutter/setup)

## License

Private project - All rights reserved
