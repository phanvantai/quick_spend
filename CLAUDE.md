# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Quick Spend is a Flutter expense tracking mobile app with voice input support and bilingual functionality (English/Vietnamese). The app uses Firebase for backend services (Auth, Firestore, AI) and features **AI-powered expense parsing** using **Gemini 2.5 Flash via Firebase AI**, with automatic categorization and Vietnamese slang support.

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
   - Understands natural language, context, and Vietnamese slang
   - Can extract multiple expenses from one input ("50k coffee and 30k parking")
   - Smart semantic categorization (food, transport, shopping, bills, health, entertainment, other)
   - Returns structured JSON parsed into ParseResult objects
   - **No API key needed** - uses Firebase project authentication automatically
   - Vietnamese slang support: "ca" (thousand), "củ/cọc" (million)
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

### Models

- **Expense** ([lib/models/expense.dart](lib/models/expense.dart)): Core data model with Firestore integration
- **Category** ([lib/models/category.dart](lib/models/category.dart)): 7 predefined categories with bilingual keywords/labels
- **AppConfig** ([lib/models/app_config.dart](lib/models/app_config.dart)): User preference model

### Localization

- Uses `easy_localization` package
- Translation files: [assets/translations/en.json](assets/translations/en.json), [assets/translations/vi.json](assets/translations/vi.json)
- Access translations with `.tr()` extension: `'key.path'.tr()`
- Named arguments supported: `'key'.tr(namedArgs: {'param': value})`

### Firebase Integration

- **firebase_core**: Core Firebase functionality
- **firebase_auth**: Authentication (prepared for anonymous sign-in)
- **cloud_firestore**: Database for expense storage (models have serialization ready)

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
// Input: "50k coffee" or "50k coffee and 30k parking"
final results = await ExpenseParser.parse(input, userId);

// Note: Now async and returns List<ParseResult>
// Can return multiple expenses if Gemini detects them

for (final result in results) {
  if (result.success && result.expense != null) {
    // result.expense contains:
    // - amount: 50000.0
    // - description: "coffee"
    // - category: ExpenseCategory.food
    // - language: "en"
    // - confidence: 0.95 (higher with Gemini)
    // - rawInput: original text
  }
}

// Parsing Strategy:
// 1. Try Gemini AI (if configured)
// 2. Fallback to rule-based parser on failure
// 3. Always returns at least one result (success or error)
```

### Onboarding Flow

- First launch shows OnboardingScreen
- User selects language (en/vi) and currency (USD/VND)
- Settings saved via PreferencesService
- AppConfigProvider manages onboarding state
- Subsequent launches go directly to HomeScreen

## Project Structure

```bash
lib/
├── main.dart                    # App entry point with EasyLocalization setup
├── models/                      # Data models
│   ├── expense.dart            # Expense with Firestore serialization
│   ├── category.dart           # Categories with bilingual support
│   └── app_config.dart         # User preferences model
├── services/                    # Business logic layer
│   ├── gemini_expense_parser.dart # AI parser (Gemini 2.5 Flash via Firebase)
│   ├── expense_parser.dart     # Main orchestrator (AI + fallback)
│   ├── amount_parser.dart      # Fallback amount extraction (with slang)
│   ├── language_detector.dart  # Fallback language detection
│   ├── categorizer.dart        # Fallback keyword categorization
│   ├── voice_service.dart      # Speech-to-text wrapper
│   └── preferences_service.dart # SharedPreferences wrapper
├── providers/                   # State management
│   └── app_config_provider.dart # App configuration state
├── screens/                     # UI screens
│   ├── onboarding_screen.dart  # Language/currency selection
│   └── home_screen.dart        # Main app with voice input
└── widgets/                     # Reusable UI components
    └── voice_input_button.dart
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

This makes voice input more natural for Vietnamese users.

### Categories

7 predefined categories with icons, colors, and bilingual keyword lists:

- Food, Transport, Shopping, Bills, Health, Entertainment, Other
- Categorizer matches keywords in description against category keyword lists
- User can override auto-categorization using `parseWithCategory()`

### Material Design 3

- App uses Material 3 theme with deep purple seed color
- Custom CardTheme with 12px border radius
- Consistent elevation and shape patterns
