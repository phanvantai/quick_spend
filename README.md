# Quick Spend - Expense Tracker

A Flutter mobile app for quickly logging expenses with voice input and automatic categorization. Supports both English and Vietnamese languages.

## Features

- 🎤 **Voice Input**: Speak your expenses naturally in Vietnamese or English
- 🤖 **AI-Powered Parsing**: Uses Gemini 2.5 Flash via Firebase AI for intelligent expense extraction
- 🌍 **Bilingual**: Full support for English and Vietnamese
- 💬 **Vietnamese Slang Support**: Understands "ca" (thousand), "củ/cọc" (million)
- ✨ **Multiple Expenses**: Parse several expenses from one input ("50k coffee and 30k parking")
- 💰 **Flexible Input Formats**:
  - "50k coffee" → 50,000 VND
  - "1.5m shopping" → 1,500,000 VND
  - "100 nghìn xăng" → 100,000 VND
  - "45 ca tiền cơm" → 45,000 VND (Vietnamese slang!)
  - "1 củ xăng" → 1,000,000 VND (Vietnamese slang!)
- 📊 **Smart Categorization**: AI categorizes based on context (food, transport, shopping, etc.)
- 🔄 **Hybrid Architecture**: Gemini AI primary + rule-based fallback for reliability
- 📈 **Statistics Dashboard**: Visual spending insights with charts and analytics
- 📱 **Bottom Navigation**: Seamless navigation between Home, Report, and Settings
- ✏️ **Edit & Delete**: Swipeable cards to edit or delete expenses
- 🎯 **Period Filtering**: View expenses by Today, Week, Month, Year, or Custom range
- 📊 **Multiple Charts**: Donut chart, trend chart, category breakdown, and top expenses

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
│   ├── expense.dart         # Expense model with SQLite integration
│   ├── category.dart        # Category definitions with bilingual support
│   ├── category_stats.dart  # Statistics for expense categories
│   ├── period_stats.dart    # Statistics for time periods
│   └── app_config.dart      # App configuration and preferences
├── services/         # Business logic
│   ├── gemini_expense_parser.dart # AI-powered parser (Gemini 2.5 Flash)
│   ├── expense_parser.dart        # Main parser orchestrator (AI + fallback)
│   ├── amount_parser.dart         # Fallback amount parser (with slang support)
│   ├── language_detector.dart     # Fallback language detection
│   ├── categorizer.dart           # Fallback keyword categorization
│   ├── voice_service.dart         # Speech-to-text wrapper
│   ├── expense_service.dart       # SQLite database operations
│   └── preferences_service.dart   # SharedPreferences wrapper
├── providers/        # State management
│   ├── app_config_provider.dart # App configuration state
│   ├── expense_provider.dart    # Expense management state
│   └── report_provider.dart     # Statistics and reports state
├── screens/          # UI screens
│   ├── onboarding_screen.dart # Language/currency selection
│   ├── main_screen.dart       # Main screen with bottom navigation
│   ├── home_screen.dart       # Expense list and input
│   ├── report_screen.dart     # Statistics and charts
│   └── settings_screen.dart   # App settings
├── widgets/          # Reusable widgets
│   ├── common/                    # Common UI components
│   │   ├── expense_card.dart      # Expense list item
│   │   ├── category_chip.dart     # Category badge
│   │   ├── empty_state.dart       # Empty list placeholder
│   │   ├── gradient_button.dart   # Custom button
│   │   └── stat_card.dart         # Statistics card
│   ├── report/                    # Report-specific widgets
│   │   ├── category_donut_chart.dart    # Category breakdown chart
│   │   ├── spending_trend_chart.dart    # Spending over time chart
│   │   ├── category_list.dart           # Category statistics list
│   │   ├── top_expenses_list.dart       # Largest expenses list
│   │   ├── summary_card.dart            # Summary statistics
│   │   ├── stats_grid.dart              # Statistics grid
│   │   ├── period_filter.dart           # Date range selector
│   │   └── custom_date_range_picker.dart # Custom date picker
│   ├── voice_input_button.dart    # Voice recording FAB
│   ├── voice_tutorial_overlay.dart # Voice input tutorial
│   └── edit_expense_dialog.dart   # Edit expense modal
├── theme/            # Design system
│   └── app_theme.dart # Theme configuration and constants
└── utils/            # Utilities
    └── date_range_helper.dart # Date range calculations

assets/
└── translations/     # Localization files
    ├── en.json       # English translations
    └── vi.json       # Vietnamese translations
```

## Phase 1 ✅ Complete

### Models Created

#### Expense Model ([lib/models/expense.dart](lib/models/expense.dart))

- Complete expense data structure
- Firestore serialization/deserialization
- Formatted amount display (VND/USD)
- Immutable with `copyWith` support

#### Category Model ([lib/models/category.dart](lib/models/category.dart))

- 7 categories: Food, Transport, Shopping, Bills, Health, Entertainment, Other
- Bilingual labels and keywords
- Material icons and colors
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
- Language selection (English 🇺🇸 / Tiếng Việt 🇻🇳)
- Currency selection (USD $ / VND đ)
- Smooth navigation to home screen
- Preferences saved automatically

### Localization System

**[assets/translations/](assets/translations/)**

- Complete i18n setup with `easy_localization`
- JSON translation files for English and Vietnamese
- Dynamic locale switching based on user preference
- Supports named arguments (e.g., `{currency}`)

**Key Features:**

- All UI text is localized
- Language changes take effect immediately
- Fallback to English if translation missing
- Easy to add new languages

### App Configuration

**[lib/models/app_config.dart](lib/models/app_config.dart)**

- User preferences model (language, currency)
- Language and currency options with display names
- JSON serialization for persistence

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

- Language selection (English/Vietnamese)
- Currency selection (USD/VND)
- App information and version
- Clean, organized UI

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

## Next Steps (Future Enhancements)

### Potential Features

- [ ] Search and filter expenses
- [ ] Expense tags and notes
- [ ] Recurring expenses
- [ ] Budget tracking and alerts
- [ ] Data export (CSV, PDF)
- [ ] Multiple currency support in single session
- [ ] Cloud backup and sync (Firebase Firestore)
- [ ] Expense attachments (receipts/photos)
- [ ] Split expenses with others

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
