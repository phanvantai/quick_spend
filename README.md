# Quick Spend - Expense Tracker

A Flutter mobile app for quickly logging expenses with voice input and automatic categorization. Supports both English and Vietnamese languages.

## Features

- 🎤 **Voice Input**: Speak your expenses naturally
- 🌍 **Bilingual**: Full support for English and Vietnamese
- 🤖 **Auto-categorization**: Smart categorization based on keywords
- 💰 **Flexible Input Formats**:
  - "50k coffee" → 50,000 VND
  - "1.5m shopping" → 1,500,000 VND
  - "100 nghìn xăng" → 100,000 VND
- 📊 **Real-time Sync**: Firebase Firestore integration
- 📈 **Statistics Dashboard**: Visual spending insights

## Tech Stack

- **Flutter** (latest stable)
- **Firebase** (Auth, Firestore)
- **Provider** (State management)
- **easy_localization** (i18n/l10n)
- **speech_to_text** (Voice input)
- **fl_chart** (Charts and graphs)
- **shared_preferences** (Local storage)

## Project Structure

```bash
lib/
├── models/           # Data models
│   ├── expense.dart       # Expense model with Firestore integration
│   ├── category.dart      # Category definitions with bilingual support
│   └── app_config.dart    # App configuration and preferences
├── services/         # Business logic
│   ├── amount_parser.dart       # Parse amounts from text
│   ├── language_detector.dart   # Detect English/Vietnamese
│   ├── categorizer.dart         # Auto-categorize expenses
│   ├── expense_parser.dart      # Main parser orchestrator
│   └── preferences_service.dart # SharedPreferences wrapper
├── providers/        # State management
│   └── app_config_provider.dart # App configuration state
├── screens/          # UI screens
│   ├── onboarding_screen.dart   # Language/currency selection
│   └── home_screen.dart         # Main app screen
├── widgets/          # Reusable widgets (TBD)
└── utils/            # Constants and helpers (TBD)

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

## Next Steps (Phase 3-6)

### Phase 3: Firebase Integration
- [ ] Firebase configuration
- [ ] Authentication service (anonymous sign-in)
- [ ] Firestore service (CRUD operations)
- [ ] ExpenseProvider for state management

### Phase 4: Voice Input
- [ ] VoiceService with speech_to_text
- [ ] Permission handling
- [ ] Bilingual voice recognition (en-US, vi-VN)

### Phase 5: Main UI Components
- [ ] ExpenseInputWidget (input bar with voice button)
- [ ] ExpenseListItem (swipeable cards)
- [ ] Expense list with real data

### Phase 6: Statistics
- [ ] StatsScreen with charts
- [ ] Period selector (Today/Week/Month)
- [ ] Category breakdown

### Phase 7: Settings & Polish
- [ ] SettingsScreen (change language/currency)
- [ ] Bottom navigation
- [ ] Edit/delete expenses
- [ ] Search and filters

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
