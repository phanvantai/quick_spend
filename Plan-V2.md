# QuickSpend V2 — Master Plan

> Rebuild from scratch. Simple, fast, voice-first expense tracking.

**Last updated:** 2026-02-26
**Platform:** iOS 17+ (SwiftUI + SwiftData)
**Languages:** English, Vietnamese (only 2 languages in v2)

---

## Vision

QuickSpend v2 is a **minimalist expense tracker for lazy people**. The core loop is dead simple:

1. Open app → tap mic → speak → done.
2. Gemini parses voice input into structured transactions.
3. User reviews and confirms. That's it.

Everything else (reports, categories, recurring) exists to support this core loop.

---

## Phase 1 — Foundation & Database Design

> **Goal:** Finalize data models, category system, and database schema before writing any UI code. Get the foundation right.

### 1.1 Category System Redesign

**Problem:** V1 has "system categories" (`isSystem = true`) that can't be deleted. This is rigid and confusing.

**V2 approach:**
- **No more system/user distinction.** All categories are equal — user can add, edit, delete any category.
- **Pre-seeded defaults** are just initial data, not special. User owns them completely after onboarding.
- **Category groups** to organize categories visually (optional, for better UX).

#### Default Categories (pre-seeded)

Researched and curated for a universal expense tracker targeting Vietnamese and English users.

**Expense Categories:**

| Group | ID | Name (EN) | Name (VI) | Icon (SF Symbol) | Color |
|-------|----|-----------|-----------|-------------------|-------|
| Daily Living | `food_drink` | Food & Drink | Ăn uống | fork.knife | #FF8C42 |
| Daily Living | `groceries` | Groceries | Đi chợ / Siêu thị | cart.fill | #8BC34A |
| Daily Living | `transport` | Transport | Di chuyển | car.fill | #5F5CF1 |
| Daily Living | `housing` | Housing | Nhà ở | house.fill | #795548 |
| Daily Living | `bills_utilities` | Bills & Utilities | Hoá đơn | bolt.fill | #FF5757 |
| Personal | `shopping` | Shopping | Mua sắm | bag.fill | #6C5CE7 |
| Personal | `health` | Health | Sức khoẻ | cross.case.fill | #4CAF50 |
| Personal | `education` | Education | Học tập | book.fill | #3F51B5 |
| Personal | `entertainment` | Entertainment | Giải trí | film.fill | #FF6B9D |
| Personal | `personal_care` | Personal Care | Chăm sóc cá nhân | sparkles | #E91E63 |
| Social | `gifts` | Gifts & Donations | Quà tặng | gift.fill | #9C27B0 |
| Social | `family` | Family | Gia đình | person.2.fill | #00BCD4 |
| Financial | `insurance` | Insurance | Bảo hiểm | shield.fill | #607D8B |
| Financial | `savings_invest` | Savings & Investment | Tiết kiệm / Đầu tư | chart.line.uptrend.xyaxis | #009688 |
| Financial | `debt_payment` | Debt Payment | Trả nợ | creditcard.fill | #F44336 |
| Other | `pets` | Pets | Thú cưng | pawprint.fill | #8D6E63 |
| Other | `travel` | Travel | Du lịch | airplane | #00ACC1 |
| Other | `other_expense` | Other | Khác | ellipsis.circle.fill | #9E9EB5 |

**Income Categories:**

| Group | ID | Name (EN) | Name (VI) | Icon (SF Symbol) | Color |
|-------|----|-----------|-----------|-------------------|-------|
| Earned | `salary` | Salary | Lương | wallet.bifold.fill | #4CAF50 |
| Earned | `freelance` | Freelance | Thu nhập tự do | laptopcomputer | #2196F3 |
| Earned | `bonus` | Bonus | Thưởng | star.fill | #FFC107 |
| Passive | `investment_income` | Investment | Thu nhập đầu tư | chart.bar.fill | #009688 |
| Passive | `interest` | Interest | Lãi suất | percent | #00BCD4 |
| Received | `gift_received` | Gift Received | Được tặng | gift.fill | #E91E63 |
| Received | `refund` | Refund | Hoàn tiền | arrow.uturn.backward.circle.fill | #FF9800 |
| Other | `other_income` | Other Income | Thu nhập khác | plus.circle.fill | #9C27B0 |

#### Category Group (optional feature)

Groups are purely for UI organization — not stored as a separate entity initially. Can be a computed property or a simple enum.

```
enum CategoryGroup: String {
    // Expense groups
    case dailyLiving, personal, social, financial
    // Income groups
    case earned, passive, received
    // Shared
    case other
}
```

### 1.2 Database Schema (SwiftData)

#### `Category` model (renamed from `QuickCategory`)

```swift
@Model
final class Category {
    @Attribute(.unique) var id: String          // e.g. "food_drink"
    var name: String                             // localized display name
    var iconName: String                         // SF Symbol name
    var colorHex: String                         // hex color code
    var type: String                             // "expense" | "income"
    var group: String?                           // optional group for UI
    var keywords: [String]                       // for AI matching
    var sortOrder: Int                           // user-defined sort order
    var isHidden: Bool                           // soft-delete / hide
    var createdAt: Date
    var updatedAt: Date
}
```

**Changes from v1:**
- Removed `isSystem` — no more system vs user distinction
- Removed `userId` — all local, single user
- Added `group` — optional grouping for UI
- Added `sortOrder` — user can reorder
- Added `isHidden` — soft-delete instead of hard delete (preserves transaction references)
- Added `updatedAt` — track modifications
- Renamed from `QuickCategory` to `Category` (cleaner)

#### `Transaction` model (renamed from `Expense`)

```swift
@Model
final class Transaction {
    @Attribute(.unique) var id: String
    var amount: Double
    var note: String                             // renamed from descriptionText
    var categoryId: String                       // references Category.id
    var type: String                             // "expense" | "income"
    var date: Date
    var rawInput: String?                        // original voice/text input (optional)
    var confidence: Double?                      // AI confidence score (optional)
    var createdAt: Date
    var updatedAt: Date
}
```

**Changes from v1:**
- Renamed from `Expense` to `Transaction` (covers both income and expense)
- Renamed `descriptionText` → `note` (simpler)
- Removed `language` — app-level setting, not per-transaction
- Removed `userId` — single user app
- `rawInput` and `confidence` are now optional (only present for AI-parsed transactions)
- Added `createdAt` / `updatedAt`

#### `RecurringTemplate` model (unchanged concept, refined schema)

```swift
@Model
final class RecurringTemplate {
    @Attribute(.unique) var id: String
    var amount: Double
    var note: String
    var categoryId: String
    var type: String                             // "expense" | "income"
    var pattern: String                          // "daily" | "weekly" | "monthly" | "yearly"
    var startDate: Date
    var endDate: Date?
    var lastGeneratedDate: Date?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}
```

**Changes from v1:**
- Added `daily` and `weekly` recurrence patterns
- Removed `language` and `userId`
- Renamed `descriptionText` → `note`

### 1.3 Simplified Onboarding

**V1 onboarding:** 3 pages (welcome → language → currency) — too many steps.

**V2 onboarding:** Single screen

```
┌─────────────────────────────┐
│                             │
│      Welcome to QuickSpend  │
│                             │
│   [🇺🇸 English]  [🇻🇳 Tiếng Việt]   │
│                             │
│   Currency: [Auto-detected] │
│   (tap to change)           │
│                             │
│   [ Get Started ]           │
│                             │
└─────────────────────────────┘
```

- Language selection auto-sets currency (EN → USD, VI → VND)
- Currency can be tapped to override
- One tap to start (no multi-page wizard)
- Seeds default categories on completion

### 1.4 App Configuration

```swift
struct AppConfig: Codable {
    var language: String           // "en" | "vi"
    var currency: String           // "USD" | "VND"
    var themeMode: String          // "system" | "light" | "dark"
    var isOnboardingComplete: Bool
}
```

**Simplified from v1:** Only 2 languages, dropped `dataCollectionConsent` (revisit later).

### 1.5 Deliverables — Phase 1

- [ ] Finalize category list (review with real users if possible)
- [ ] Create SwiftData models: `Category`, `Transaction`, `RecurringTemplate`
- [ ] Create `TransactionType` and `RecurrencePattern` enums
- [ ] Create `CategoryGroup` enum
- [ ] Implement `CategoryService` — seed default categories, CRUD operations
- [ ] Implement simplified `AppConfig` and `PreferencesService`
- [ ] Implement single-screen `OnboardingView`
- [ ] Write model unit tests
- [ ] Verify SwiftData persistence works correctly

---

## Phase 2 — Core UI & Manual Input

> **Goal:** Build the essential screens. Users can manually add, edit, delete transactions and manage categories.

### 2.1 Tab Structure

```
┌──────────────────────────────┐
│         MainTabView          │
├──────────────────────────────┤
│                              │
│      [Current Tab Content]   │
│                              │
├──────────┬──────┬────────────┤
│  Home    │  +   │  Settings  │
│  (house) │(mic) │  (gear)    │
└──────────┴──────┴────────────┘
```

- **2 tabs + center FAB** (simplified from 3 tabs)
- Home = overview + transaction list (merged)
- Settings = all settings + category management
- Center FAB = voice input (primary action)

### 2.2 Home Screen

```
┌─────────────────────────────┐
│  ◄ February 2026 ►          │
├─────────────────────────────┤
│  Balance     ₫2,500,000     │
│  Income  ↑   ₫5,000,000     │
│  Expense ↓   ₫2,500,000     │
├─────────────────────────────┤
│  Today                      │
│  ┌─ 🍔 Lunch    -₫45,000 ─┐│
│  └─ 💰 Salary +₫5,000,000 ─┘│
│                              │
│  Yesterday                   │
│  ┌─ 🛒 Groceries -₫120,000 ┐│
│  └─ 🚗 Grab     -₫35,000  ─┘│
│  ...                         │
└─────────────────────────────┘
```

- Monthly summary at top (balance, income, expense)
- Transaction list grouped by date (scrollable)
- Tap transaction → edit
- Swipe to delete
- Month navigator to switch months

### 2.3 Transaction Form

- Amount input (numeric keypad)
- Category picker (grid with icons)
- Date picker (default: today)
- Note (optional text field)
- Type toggle (expense/income)
- Save / Delete buttons

### 2.4 Category Management (in Settings)

- List all categories grouped by type (expense/income)
- Add new category: name, icon picker, color picker, type, group
- Edit category: same form
- Delete category: soft-delete (set `isHidden = true`), reassign transactions option
- Reorder categories (drag & drop)

### 2.5 Settings Screen

- Language (EN / VI)
- Currency (USD / VND)
- Theme (System / Light / Dark)
- Categories → Category management screen
- About / Version

### 2.6 Deliverables — Phase 2

- [ ] `MainTabView` with 2 tabs + center FAB
- [ ] `HomeView` — monthly summary + transaction list
- [ ] `TransactionFormView` — add/edit transaction
- [ ] `CategoryPickerView` — icon grid for selecting category
- [ ] `CategoriesView` — list, add, edit, delete, reorder
- [ ] `CategoryFormView` — create/edit category
- [ ] `SettingsView` — language, currency, theme, categories link
- [ ] Navigation flow between all screens
- [ ] Swipe-to-delete on transactions
- [ ] Month navigation on Home

---

## Phase 3 — Voice Input & AI Parsing

> **Goal:** The killer feature. Speak naturally, Gemini parses it into transactions.

### 3.1 Voice Input Flow

```
User taps mic FAB
        ↓
┌──────────────────┐
│  🎙 Listening...  │
│                    │
│  "I spent 50k on  │
│   lunch and 30k   │
│   on coffee"      │
│                    │
│  [Cancel]  [Done]  │
└──────────────────┘
        ↓
   Gemini parses
        ↓
┌──────────────────┐
│  Parsed Results   │
│                    │
│  ☑ Lunch  -₫50,000│
│  ☑ Coffee -₫30,000│
│                    │
│  [Edit] [Save All] │
└──────────────────┘
```

### 3.2 Gemini Integration

- Use Firebase AI (Gemini 2.5 Flash) for parsing
- Smart prompt with:
  - Current date context
  - Available categories + keywords
  - Language context (EN/VI)
  - Vietnamese slang support ("ca" = nghìn, "củ" = triệu)
- Returns structured JSON with category, amount, note, type, date, confidence
- Fallback: manual entry form if parsing fails

### 3.3 Voice Service

- Native `Speech` framework for speech-to-text
- Real-time transcription display
- Sound level visualization
- Permission handling (microphone + speech recognition)

### 3.4 Deliverables — Phase 3

- [ ] `VoiceService` — speech recognition with real-time transcription
- [ ] `GeminiParserService` — natural language → structured transactions
- [ ] Voice overlay UI (listening state, transcription display)
- [ ] Parsed results review dialog (confirm, edit, save)
- [ ] Fallback to manual entry on parse failure
- [ ] Vietnamese slang/abbreviation support
- [ ] Usage limit tracking (free tier: 5 parses/day)

---

## Phase 4 — Reports & Insights

> **Goal:** Help users understand their spending with clear, simple reports.

### 4.1 Report Features

- **Monthly summary:** Total income, expense, balance, savings rate
- **Category breakdown:** Pie/donut chart showing spending by category
- **Top expenses:** List of highest transactions
- **Trend chart:** 6-month or 12-month bar chart (income vs expense)
- **Daily average:** Average spending per day

### 4.2 Report Screen

Accessible from Home screen (e.g., "View Report" button or swipe up).

```
┌─────────────────────────────┐
│  February 2026 Report       │
├─────────────────────────────┤
│  [Donut Chart]              │
│   Food 35% | Transport 20%  │
│   Shopping 15% | ...         │
├─────────────────────────────┤
│  Daily Average: ₫85,000     │
│  Savings Rate: 50%          │
├─────────────────────────────┤
│  Top Expenses               │
│  1. Rent        ₫5,000,000  │
│  2. Groceries   ₫1,200,000  │
│  ...                         │
├─────────────────────────────┤
│  [6-Month Trend Bar Chart]  │
└─────────────────────────────┘
```

### 4.3 Deliverables — Phase 4

- [ ] `ReportView` — monthly report screen
- [ ] `PeriodStats` computation service
- [ ] Category breakdown donut/pie chart (Swift Charts)
- [ ] Monthly trend bar chart (Swift Charts)
- [ ] Top expenses list
- [ ] Daily average / savings rate calculations
- [ ] Date range selection (this month, last month, custom)

---

## Phase 5 — Recurring Transactions

> **Goal:** Automate repetitive transactions (rent, subscriptions, salary).

### 5.1 Features

- Create recurring templates with pattern (daily/weekly/monthly/yearly)
- Auto-generate transactions based on schedule
- Enable/disable templates
- Set end date (optional)
- View and manage all recurring templates

### 5.2 Deliverables — Phase 5

- [ ] `RecurringService` — auto-generate transactions from templates
- [ ] `RecurringListView` — list all templates
- [ ] `RecurringFormView` — create/edit template
- [ ] Auto-generation on app launch
- [ ] Toggle active/inactive
- [ ] End date support

---

## Phase 6 — Subscription & Monetization

> **Goal:** Implement freemium model with RevenueCat.

### 6.1 Free Tier Limits

| Feature | Free | Pro |
|---------|------|-----|
| AI voice parses | 5 / day | Unlimited |
| Recurring templates | 3 max | Unlimited |
| Report history | 7 days | Unlimited |
| Categories | Unlimited | Unlimited |
| Manual entry | Unlimited | Unlimited |

### 6.2 Deliverables — Phase 6

- [ ] RevenueCat integration
- [ ] `SubscriptionViewModel` — manage subscription state
- [ ] `PaywallView` — purchase screen
- [ ] Feature gating throughout the app
- [ ] Restore purchases
- [ ] Receipt validation

---

## Phase 7 — Polish & Quality

> **Goal:** Refine the experience. Animations, haptics, edge cases, performance.

### 7.1 Deliverables — Phase 7

- [ ] Haptic feedback on key actions (save, delete, voice start/stop)
- [ ] Smooth animations and transitions
- [ ] Empty states (no transactions, no categories)
- [ ] Error handling and user-friendly error messages
- [ ] Loading states and skeleton screens
- [ ] Keyboard avoidance and input UX
- [ ] Dark mode polish
- [ ] Accessibility (VoiceOver, Dynamic Type)
- [ ] Performance optimization (lazy loading, pagination)
- [ ] Memory leak audit

---

## Phase 8 — Advanced Features (Post-Launch)

> **Goal:** Features to add after v2 initial launch, based on user feedback.

### 8.1 Potential Features

- **Budget system:** Set monthly budgets per category, track progress
- **Widgets:** iOS home screen widgets (today's spending, monthly summary)
- **Export:** CSV/PDF export of transactions
- **Search:** Full-text search across transactions
- **Tags:** Additional tagging system beyond categories
- **Multi-currency per transaction:** Record transactions in different currencies
- **Photo receipts:** Attach photos to transactions, OCR parsing
- **Notifications:** Daily reminder to log expenses, budget alerts
- **Cloud sync:** Firebase/iCloud sync across devices
- **More languages:** Japanese, Korean, Thai, Spanish (re-add from v1)
- **Apple Watch:** Quick voice input from watch
- **Shortcuts integration:** Siri Shortcuts for quick expense entry

---

## Technical Decisions

### Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (iOS 17+) |
| Data | SwiftData |
| AI | Firebase AI (Gemini 2.5 Flash) |
| Voice | Native Speech framework |
| Analytics | Firebase Analytics |
| Subscriptions | RevenueCat |
| Charts | Swift Charts |
| Architecture | MVVM + Service Layer |

### Design Principles

1. **Simple first.** If a feature adds complexity without clear value, skip it.
2. **Voice-first.** Every design decision should make voice input the easiest path.
3. **Offline-first.** App works fully offline. Cloud features are optional.
4. **2 languages only.** English and Vietnamese. Do them well, don't spread thin.
5. **No premature abstraction.** Build what's needed now, refactor when patterns emerge.

### Naming Conventions

- Models: `Category`, `Transaction`, `RecurringTemplate` (no prefix)
- Services: `*Service` suffix (e.g., `CategoryService`, `GeminiParserService`)
- ViewModels: `*ViewModel` suffix (e.g., `AppConfigViewModel`)
- Views: descriptive names (e.g., `HomeView`, `TransactionFormView`)
- Private methods: `_` prefix (e.g., `_initializeFirebase()`)

---

## Timeline Overview

| Phase | Focus | Dependencies |
|-------|-------|-------------|
| Phase 1 | Foundation & Database | None |
| Phase 2 | Core UI & Manual Input | Phase 1 |
| Phase 3 | Voice & AI | Phase 2 |
| Phase 4 | Reports | Phase 2 |
| Phase 5 | Recurring | Phase 2 |
| Phase 6 | Subscription | Phase 3, 4, 5 |
| Phase 7 | Polish | Phase 6 |
| Phase 8 | Advanced (post-launch) | Phase 7 |

> Phase 3, 4, 5 can be developed in parallel after Phase 2 is complete.

---

## Current Status

- [x] **V1 completed** (Flutter → SwiftUI migration done)
- [ ] **Phase 1** — In planning ← WE ARE HERE
- [ ] **Phase 2** — Not started
- [ ] **Phase 3** — Not started
- [ ] **Phase 4** — Not started
- [ ] **Phase 5** — Not started
- [ ] **Phase 6** — Not started
- [ ] **Phase 7** — Not started
- [ ] **Phase 8** — Post-launch backlog
