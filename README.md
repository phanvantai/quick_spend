# Quick Spend - Expense Tracker

A Flutter mobile app for quickly logging expenses and income with voice input and AI-powered categorization. Supports 6 languages and 6 currencies.

## Features

- 🎤 **Voice Input** - Speak expenses naturally in 6 languages (English, Vietnamese, Japanese, Korean, Thai, Spanish)
- 🤖 **AI-Powered Parsing** - Gemini 2.5 Flash via Firebase AI for intelligent expense extraction
- 💬 **Vietnamese Slang Support** - Understands "ca" (thousand), "củ/cọc" (million), incomplete words
- ✨ **Multiple Expenses** - Extract multiple expenses from one input ("50k coffee and 30k parking")
- 📅 **Date Parsing** - Understands "yesterday", "hôm qua", "last week", "3 days ago"
- 💰 **Income & Expense Tracking** - Full support for both with dedicated categories
- 📂 **13 Default Categories** - 7 expense + 6 income categories, fully localized
- ➕ **Custom Categories** - Create your own with custom icons, colors, and keywords
- 🔁 **Recurring Expenses** - Set up monthly/yearly recurring transactions
- 📈 **Statistics Dashboard** - Visual insights with interactive charts
- 📅 **Calendar View** - Monthly calendar with daily income/expense totals
- 📤 **Import/Export** - JSON (full backup) or CSV (expenses only)
- 🎨 **Dark Mode** - Complete light/dark theme support
- 🔒 **Privacy-First** - All data stored locally, optional anonymized ML training data

## Tech Stack

- **Flutter** - Cross-platform mobile framework
- **SQLite** (sqflite) - Local database
- **Firebase AI** - Gemini 2.5 Flash for expense parsing
- **Firebase Analytics** - User behavior tracking (no PII)
- **Provider** - State management
- **easy_localization** - Internationalization
- **speech_to_text** - Voice input
- **fl_chart** - Charts and graphs

## Usage Examples

### Voice Input

Long press the voice button, speak naturally, then release:

```text
"50k coffee" → 50,000 VND, Category: Food
"100k xăng" → 100,000 VND, Category: Transport
"1 triệu 5 mua sắm" → 1,500,000 VND, Category: Shopping
"45 ca tiền cơm hôm qua" → 45,000 VND, Category: Food, Date: Yesterday
"50k coffee and 30k parking" → 2 expenses automatically
```

### Programmatic Parsing

```dart
import 'package:quick_spend/services/expense_parser.dart';

// Parse English input
final results = await ExpenseParser.parse(
  "50k coffee",
  "user123",
  categories,
  language: 'en',
);

// Parse Vietnamese with slang
final results = await ExpenseParser.parse(
  "45 ca tiền cơm",
  "user123",
  categories,
  language: 'vi',
);
```

## Development

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Run tests
flutter test

# Code analysis
flutter analyze
```

## Architecture

### State Management

- **Provider** pattern with separate providers for app config, expenses, categories, reports, recurring templates

### Services Layer

- **ExpenseParser** - Main orchestrator (tries Gemini → falls back to rules)
- **GeminiExpenseParser** - AI-powered parsing with Gemini 2.5 Flash
- **DatabaseManager** - Centralized SQLite management (schema v3)
- **VoiceService** - Speech-to-text wrapper with permission handling
- **AnalyticsService** - Firebase Analytics integration (privacy-safe)

### Database

- **SQLite** with sqflite (local-first architecture)
- Tables: `expenses`, `categories`, `recurring_templates`
- Current schema version: 3

## Categories

**Expense Categories (7):**

- Food 🍽️ | Transport 🚗 | Shopping 🛍️ | Bills 📄 | Health 🏥 | Entertainment 🎬 | Other 📦

**Income Categories (6):**

- Salary 💼 | Freelance 💻 | Investment 📈 | Gift Received 🎁 | Refund 💸 | Other Income 💰

All categories are fully localized in 6 languages with keyword lists for automatic categorization.

## TODO - Future Enhancements

### Search & Filtering

- [ ] Search expenses by keyword or description
- [ ] Filter expenses by amount range (min/max)
- [ ] Filter by multiple categories at once
- [ ] Advanced search with multiple criteria

### Budgeting & Alerts

- [ ] Budget tracking by category
- [ ] Monthly/weekly budget limits
- [ ] Budget alerts and notifications
- [ ] Budget vs actual spending reports

### Export & Reporting

- [ ] PDF export with charts and summaries
- [ ] Email export with formatted reports
- [ ] Custom report templates

### Multi-Currency

- [ ] Multiple currency support in single session
- [ ] Multi-currency expenses with exchange rates
- [ ] Automatic currency conversion

### Cloud & Sync

- [ ] Cloud backup and sync (Firebase Firestore)
- [ ] Multi-device synchronization
- [ ] Account system with email/password

### Social Features

- [ ] Split expenses with others
- [ ] Group expense tracking
- [ ] Shared budgets with family/friends

### Security & Privacy

- [ ] Biometric authentication (Face ID/Touch ID/Fingerprint)
- [ ] PIN/password lock
- [ ] Encrypted database

### AI & Intelligence

- [ ] Receipt scanning with OCR
- [ ] Merchant name extraction
- [ ] Spending pattern analysis
- [ ] Anomaly detection
- [ ] Predictive budgeting

### Platform Features

- [ ] iPad/tablet optimized layout
- [ ] Desktop support (macOS/Windows/Linux)
- [ ] Web app version
- [ ] Apple Watch/Wear OS companion app

### Integrations

- [ ] Bank account integration (read-only)
- [ ] Credit card import
- [ ] Payment app integrations (PayPal, Venmo, etc.)
- [ ] Export to accounting software (QuickBooks, Xero)

### Miscellaneous

- [ ] Home screen widgets for quick expense entry
- [ ] More languages (French, German, Italian, Portuguese, Chinese, Arabic, etc.)
- [ ] Expense tags and notes
- [ ] Expense attachments (receipts/photos)
- [ ] Bulk operations
- [ ] Custom themes and icon packs

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase for Flutter](https://firebase.google.com/docs/flutter/setup)
- [Design System Documentation](DESIGN_SYSTEM.md)
- [Project Instructions for Claude Code](CLAUDE.md)

## License

MIT License - See [LICENSE](LICENSE) file for details
