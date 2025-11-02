# Quick Spend Design System

A comprehensive, modern design system for the Quick Spend expense tracking app.

## Table of Contents

- [Overview](#overview)
- [Color Palette](#color-palette)
- [Typography](#typography)
- [Spacing System](#spacing-system)
- [Components](#components)
- [Usage Guidelines](#usage-guidelines)

## Overview

The Quick Spend design system provides a cohesive visual language with:

- **Modern aesthetic**: Purple-blue gradient theme with vibrant accents
- **Material Design 3**: Full MD3 compliance
- **Accessibility**: WCAG AA compliant color contrasts
- **Dark mode ready**: Complete dark theme support
- **Bilingual**: Optimized for English and Vietnamese

## Color Palette

### Primary Colors

```dart
Primary Purple: #6C5CE7
Primary Blue: #5F5CF1
Primary Dark: #5145CD
```

- **Usage**: Primary actions, headers, key UI elements
- **Gradient**: Purple to Blue (top-left to bottom-right)

### Secondary/Accent Colors

```dart
Accent Pink: #FF6B9D
Accent Orange: #FF8C42
Accent Teal: #00D9C0
```

- **Usage**: Call-to-actions, highlights, voice recording states
- **Gradient**: Pink to Orange for special emphasis

### Neutral Colors

```dart
Neutral 900 (Darkest): #1A1A2E
Neutral 800: #2D2D44
Neutral 700: #3F3F5A
Neutral 600: #6B6B85
Neutral 500: #9E9EB5
Neutral 400: #BFBFD0
Neutral 300: #DDDDE5
Neutral 200: #EEEEF5
Neutral 100: #F7F7FB
Neutral 50 (Lightest): #FBFBFD
```

- **Usage**: Text, backgrounds, borders, surfaces

### Semantic Colors

```dart
Success: #00C896 (Green)
Warning: #FFC043 (Yellow/Orange)
Error: #FF5757 (Red)
Info: #5F5CF1 (Blue)
```

### Category Colors

```dart
Food: #FF8C42 (Orange)
Transport: #5F5CF1 (Blue)
Shopping: #6C5CE7 (Purple)
Bills: #FF5757 (Red)
Health: #00C896 (Green)
Entertainment: #FF6B9D (Pink)
Other: #9E9EB5 (Gray)
```

## Typography

### Font System

- **Font Family**: Inter (or system default)
- **Base Size**: 16px body text
- **Scale**: Material Design 3 type scale

### Text Styles

#### Display (Largest)

- **Display Large**: 57px, Bold (700), -0.25 letter-spacing
- **Display Medium**: 45px, Bold (700), 0 letter-spacing
- **Display Small**: 36px, Semi-bold (600), 0 letter-spacing

#### Headlines

- **Headline Large**: 32px, Semi-bold (600)
- **Headline Medium**: 28px, Semi-bold (600)
- **Headline Small**: 24px, Semi-bold (600)

#### Titles

- **Title Large**: 22px, Semi-bold (600)
- **Title Medium**: 16px, Semi-bold (600), 0.15 letter-spacing
- **Title Small**: 14px, Semi-bold (600), 0.1 letter-spacing

#### Body

- **Body Large**: 16px, Regular (400), 0.5 letter-spacing
- **Body Medium**: 14px, Regular (400), 0.25 letter-spacing
- **Body Small**: 12px, Regular (400), 0.4 letter-spacing

#### Labels (Buttons/Chips)

- **Label Large**: 14px, Semi-bold (600), 0.1 letter-spacing
- **Label Medium**: 12px, Semi-bold (600), 0.5 letter-spacing
- **Label Small**: 11px, Semi-bold (600), 0.5 letter-spacing

## Spacing System

### Base Unit: 4px

```dart
Spacing 4: 4px
Spacing 8: 8px
Spacing 12: 12px
Spacing 16: 16px (default padding)
Spacing 20: 20px
Spacing 24: 24px (card/section padding)
Spacing 32: 32px (large gaps)
Spacing 40: 40px
Spacing 48: 48px
Spacing 64: 64px (extra large gaps)
```

### Border Radius

```dart
Radius Small: 8px (chips, tags)
Radius Medium: 12px (buttons, cards, inputs)
Radius Large: 16px (large cards, dialogs)
Radius XLarge: 24px (hero elements)
Radius Full: 999px (circular)
```

### Shadows

#### Small Shadow

- Offset: (0, 2)
- Blur: 4px
- Opacity: 5%

#### Medium Shadow

- Offset: (0, 4)
- Blur: 12px
- Opacity: 10%

#### Large Shadow

- Offset: (0, 8)
- Blur: 24px
- Opacity: 15%

#### XLarge Shadow

- Offset: (0, 12)
- Blur: 32px
- Opacity: 20%

## Components

### Buttons

#### Filled Button (Primary)

- **Background**: Primary gradient or solid color
- **Text**: White, Label Large style
- **Padding**: 24px horizontal, 16px vertical
- **Border Radius**: 12px
- **Elevation**: 0 (flat)
- **Usage**: Primary actions, CTAs

#### Elevated Button

- **Background**: White
- **Text**: Primary color
- **Padding**: 24px horizontal, 16px vertical
- **Border Radius**: 12px
- **Elevation**: Shadow medium
- **Usage**: Secondary important actions

#### Outlined Button

- **Background**: Transparent
- **Border**: 1px Neutral 300
- **Text**: Primary color
- **Padding**: 24px horizontal, 16px vertical
- **Border Radius**: 12px
- **Usage**: Tertiary actions, Cancel buttons

#### Text Button

- **Background**: Transparent
- **Text**: Primary color
- **Padding**: 16px horizontal, 12px vertical
- **Usage**: Low-priority actions, inline links

#### Gradient Button (Custom)

- **Background**: Customizable gradient
- **Icon**: Optional leading icon
- **Loading State**: Circular progress indicator
- **Full Width**: Optional
- **Usage**: Hero CTAs, special emphasis

### Cards

#### Standard Card

- **Background**: White (light), Neutral 800 (dark)
- **Border**: 1px Neutral 200
- **Border Radius**: 12px
- **Elevation**: 0 (uses border instead)
- **Padding**: 16px
- **Usage**: Content containers, list items

#### Expense Card

- **Layout**: Icon (48x48) + Details + Amount
- **Category Icon**: Colored background (15% opacity)
- **Metadata**: Category label + date
- **Confidence Badge**: Shown if < 80%
- **Interaction**: Tap for details, long-press for actions

#### Stat Card

- **Icon**: Colored background container
- **Value**: Large number (Headline Medium)
- **Title**: Body Small, neutral color
- **Trend**: Optional badge (up/down indicator)
- **Usage**: Dashboard metrics, summaries

### Chips & Tags

#### Category Chip

- **Layout**: Icon + Label
- **Background**: Neutral 100 (unselected), Category color 15% (selected)
- **Border**: 1px (double width when selected)
- **Border Radius**: 8px
- **Padding**: 12px horizontal, 8px vertical
- **Usage**: Category selection, filters

### Input Fields

#### Text Input

- **Background**: Neutral 100 (filled)
- **Border**: 1px Neutral 300
- **Border Radius**: 12px
- **Padding**: 16px
- **Focus State**: 2px Primary border
- **Error State**: 2px Error border
- **Label**: Floating label (Body Medium)

### Dialogs & Modals

#### Dialog

- **Background**: White
- **Border Radius**: 16px (large)
- **Elevation**: 24
- **Max Width**: 560px
- **Padding**: 24px
- **Title**: Headline Small
- **Content**: Body Medium
- **Actions**: Right-aligned buttons

### Empty States

#### Empty State Component

- **Icon**: Large circular gradient background (120x120)
- **Icon Size**: 64px white icon
- **Title**: Headline Small
- **Message**: Body Medium, Neutral 600
- **Action**: Optional FilledButton with icon
- **Usage**: No data, onboarding prompts

### App Bar

#### Large App Bar (Sliver)

- **Expanded Height**: 200px
- **Background**: Primary gradient
- **Title**: White text, Headline Medium
- **Actions**: White icons
- **Scroll Behavior**: Collapses to standard height

### FAB (Floating Action Button)

#### Voice Recording FAB

- **Background**: Primary gradient (idle), Accent gradient (recording)
- **Shape**: Extended (pill-shaped)
- **Border Radius**: 16px (large)
- **Padding**: 24px horizontal, 16px vertical
- **Shadow**: Large
- **Icon + Label**: Mic icon + text
- **Interaction**: Long-press to record, swipe up to cancel

## Usage Guidelines

### Accessing the Theme

```dart
import 'package:quick_spend/theme/app_theme.dart';

// In MaterialApp
theme: AppTheme.lightTheme,
darkTheme: AppTheme.darkTheme,

// Accessing colors
color: AppTheme.primaryMint,
gradient: AppTheme.primaryGradient,

// Accessing spacing
padding: EdgeInsets.all(AppTheme.spacing16),

// Accessing typography
style: AppTheme.lightTextTheme.headlineSmall,

// Accessing shadows
boxShadow: AppTheme.shadowMedium,
```

### Using Components

```dart
// Gradient Button
GradientButton(
  text: 'Get Started',
  icon: Icons.arrow_forward,
  onPressed: () {},
  gradient: AppTheme.primaryGradient, // optional
)

// Category Chip
CategoryChip(
  category: ExpenseCategory.food,
  language: 'en',
  isSelected: true,
  onTap: () {},
)

// Expense Card
ExpenseCard(
  expense: myExpense,
  onTap: () {},
  onLongPress: () {},
)

// Stat Card
StatCard(
  title: 'Total Spent',
  value: '\$1,234.56',
  icon: Icons.account_balance_wallet,
  color: AppTheme.primaryMint,
  trend: '+12%',
  isPositiveTrend: false,
)

// Empty State
EmptyState(
  icon: Icons.receipt_long,
  title: 'No expenses yet',
  message: 'Start tracking your spending...',
  actionLabel: 'Add Expense',
  onAction: () {},
)
```

### Color Usage Best Practices

1. **Consistency**: Always use theme colors, never hardcode
2. **Contrast**: Ensure WCAG AA compliance (4.5:1 for text)
3. **Semantic**: Use semantic colors for their intended purpose
4. **Gradients**: Reserve for hero elements and primary CTAs
5. **Category Colors**: Only use for category-specific UI

### Typography Best Practices

1. **Hierarchy**: Use size and weight to establish visual hierarchy
2. **Line Height**: Default 1.2-1.5 for readability
3. **Letter Spacing**: Follow Material Design guidelines
4. **Localization**: Test with both English and Vietnamese
5. **Accessibility**: Minimum 12px font size

### Spacing Best Practices

1. **Consistency**: Use the 4px grid system
2. **Breathing Room**: Prefer generous spacing for clarity
3. **Rhythm**: Use consistent spacing patterns
4. **Responsive**: Adjust spacing for different screen sizes
5. **Optical Alignment**: Sometimes visual balance trumps exact measurements

## Dark Mode

The design system includes a complete dark theme with:

- **Surfaces**: Neutral 900 (background), Neutral 800 (cards)
- **Text**: Neutral 50 (primary), Neutral 300 (secondary)
- **Elevated Surfaces**: Use lighter neutral shades
- **Borders**: Neutral 700
- **Shadows**: Higher opacity black shadows

Access via:

```dart
themeMode: ThemeMode.dark, // or ThemeMode.system
```

## Accessibility

### Color Contrast

All color combinations meet WCAG AA standards:

- Text on backgrounds: ≥ 4.5:1
- Large text (18px+): ≥ 3:1
- UI components: ≥ 3:1

### Touch Targets

Minimum touch target size: 48x48dp (following Material Design)

### Screen Readers

- Semantic widgets used throughout
- Proper labels on all interactive elements
- Meaningful content descriptions

## File Structure

```bash
lib/
├── theme/
│   └── app_theme.dart          # Complete theme configuration
├── widgets/
│   └── common/
│       ├── gradient_button.dart
│       ├── category_chip.dart
│       ├── expense_card.dart
│       ├── stat_card.dart
│       └── empty_state.dart
└── screens/
    ├── home_screen_new.dart    # Modern redesigned home
    └── onboarding_screen.dart  # Onboarding flow
```

## Future Enhancements

- [ ] Custom font family (Inter or similar)
- [ ] Animation presets
- [ ] Illustration system
- [ ] Icon library expansion
- [ ] Responsive breakpoints
- [ ] Theme customization (user preferences)
- [ ] High contrast mode
- [ ] Reduced motion support
