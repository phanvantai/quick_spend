import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Quick Spend App Theme Configuration
/// Provides a cohesive, modern design system with light and dark modes
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // ============================================
  // COLOR PALETTE
  // ============================================

  // Primary colors - Mint Green gradient theme
  static const Color primaryMint = Color(0xFF00D9A3);
  static const Color primaryGreen = Color(0xFF00C896);
  static const Color primaryDark = Color(0xFF00B386);

  // Secondary colors - Accent pops
  static const Color accentPink = Color(0xFFFF6B9D);
  static const Color accentOrange = Color(0xFFFF8C42);
  static const Color accentTeal = Color(0xFF00D9C0);

  // Neutral colors
  static const Color neutral900 = Color(0xFF1A1A2E);
  static const Color neutral800 = Color(0xFF2D2D44);
  static const Color neutral700 = Color(0xFF3F3F5A);
  static const Color neutral600 = Color(0xFF6B6B85);
  static const Color neutral500 = Color(0xFF9E9EB5);
  static const Color neutral400 = Color(0xFFBFBFD0);
  static const Color neutral300 = Color(0xFFDDDDE5);
  static const Color neutral200 = Color(0xFFEEEEF5);
  static const Color neutral100 = Color(0xFFF7F7FB);
  static const Color neutral50 = Color(0xFFFBFBFD);

  // Semantic colors
  static const Color success = Color(0xFF00C896);
  static const Color warning = Color(0xFFFFC043);
  static const Color error = Color(0xFFFF5757);
  static const Color info = Color(0xFF5F5CF1);

  // Category colors (matching existing categories)
  static const Color categoryFood = Color(0xFFFF8C42);
  static const Color categoryTransport = Color(0xFF5F5CF1);
  static const Color categoryShopping = Color(0xFF6C5CE7);
  static const Color categoryBills = Color(0xFFFF5757);
  static const Color categoryHealth = Color(0xFF00C896);
  static const Color categoryEntertainment = Color(0xFFFF6B9D);
  static const Color categoryOther = Color(0xFF9E9EB5);

  // ============================================
  // GRADIENTS
  // ============================================

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryMint, primaryGreen],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentPink, accentOrange],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [neutral50, neutral100],
  );

  // Professional gradient for financial summary cards
  static const LinearGradient summaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1e3a8a), Color(0xFF3b82f6)], // Deep blue to bright blue
  );

  // ============================================
  // TYPOGRAPHY
  // ============================================

  static const String fontFamily = 'Inter'; // You can add custom font later

  static const TextTheme lightTextTheme = TextTheme(
    // Display styles (largest)
    displayLarge: TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.25,
      color: neutral900,
      height: 1.2,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      color: neutral900,
      height: 1.2,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: neutral900,
      height: 1.2,
    ),

    // Headline styles
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: neutral900,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: neutral900,
      height: 1.3,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: neutral900,
      height: 1.3,
    ),

    // Title styles
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: neutral900,
      height: 1.4,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      color: neutral900,
      height: 1.5,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: neutral900,
      height: 1.4,
    ),

    // Body styles
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      color: neutral700,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      color: neutral700,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      color: neutral600,
      height: 1.4,
    ),

    // Label styles (buttons, tabs)
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: neutral900,
      height: 1.4,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: neutral900,
      height: 1.4,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: neutral700,
      height: 1.4,
    ),
  );

  static final TextTheme darkTextTheme = lightTextTheme.apply(
    bodyColor: neutral100,
    displayColor: neutral50,
  );

  // ============================================
  // SPACING
  // ============================================

  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;
  static const double spacing64 = 64.0;

  // ============================================
  // BORDER RADIUS
  // ============================================

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;
  static const double radiusFull = 999.0;

  static const BorderRadius borderRadiusSmall = BorderRadius.all(
    Radius.circular(radiusSmall),
  );
  static const BorderRadius borderRadiusMedium = BorderRadius.all(
    Radius.circular(radiusMedium),
  );
  static const BorderRadius borderRadiusLarge = BorderRadius.all(
    Radius.circular(radiusLarge),
  );
  static const BorderRadius borderRadiusXLarge = BorderRadius.all(
    Radius.circular(radiusXLarge),
  );

  // ============================================
  // SHADOWS
  // ============================================

  static final List<BoxShadow> shadowSmall = [
    BoxShadow(
      color: neutral900.withValues(alpha: 0.05),
      offset: const Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  static final List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: neutral900.withValues(alpha: 0.1),
      offset: const Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  static final List<BoxShadow> shadowLarge = [
    BoxShadow(
      color: neutral900.withValues(alpha: 0.15),
      offset: const Offset(0, 8),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];

  static final List<BoxShadow> shadowXLarge = [
    BoxShadow(
      color: neutral900.withValues(alpha: 0.2),
      offset: const Offset(0, 12),
      blurRadius: 32,
      spreadRadius: 0,
    ),
  ];

  // ============================================
  // LIGHT THEME
  // ============================================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color scheme
      colorScheme: ColorScheme.light(
        primary: primaryMint,
        onPrimary: Colors.white,
        primaryContainer: primaryMint.withValues(alpha: 0.1),
        onPrimaryContainer: primaryDark,

        secondary: accentPink,
        onSecondary: Colors.white,
        secondaryContainer: accentPink.withValues(alpha: 0.1),
        onSecondaryContainer: accentPink,

        tertiary: accentTeal,
        onTertiary: Colors.white,
        tertiaryContainer: accentTeal.withValues(alpha: 0.1),
        onTertiaryContainer: accentTeal,

        error: error,
        onError: Colors.white,
        errorContainer: error.withValues(alpha: 0.1),
        onErrorContainer: error,

        surface: neutral50,
        onSurface: neutral900,
        surfaceContainerHighest: neutral100,
        onSurfaceVariant: neutral700,

        outline: neutral300,
        outlineVariant: neutral200,

        shadow: neutral900.withValues(alpha: 0.1),
        scrim: neutral900.withValues(alpha: 0.5),

        inverseSurface: neutral900,
        onInverseSurface: neutral50,
        inversePrimary: primaryMint.withValues(alpha: 0.7),
      ),

      // Typography
      textTheme: lightTextTheme,

      // App bar theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: neutral50,
        foregroundColor: neutral900,
        titleTextStyle: lightTextTheme.titleLarge,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shadowColor: neutral900.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadiusMedium,
          side: BorderSide(color: neutral200, width: 1),
        ),
        margin: const EdgeInsets.all(0),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: neutral100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacing16,
          vertical: spacing16,
        ),
        border: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: BorderSide(color: neutral300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: BorderSide(color: neutral300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: const BorderSide(color: primaryMint, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: const BorderSide(color: error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: const BorderSide(color: error, width: 2),
        ),
        labelStyle: lightTextTheme.bodyMedium?.copyWith(color: neutral600),
        hintStyle: lightTextTheme.bodyMedium?.copyWith(color: neutral500),
      ),

      // Button themes
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryMint,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing24,
            vertical: spacing16,
          ),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusMedium),
          elevation: 0,
          textStyle: lightTextTheme.labelLarge,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: primaryMint,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing24,
            vertical: spacing16,
          ),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusMedium),
          elevation: 0,
          shadowColor: neutral900.withValues(alpha: 0.1),
          textStyle: lightTextTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryMint,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing24,
            vertical: spacing16,
          ),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusMedium),
          side: BorderSide(color: neutral300, width: 1),
          textStyle: lightTextTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryMint,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing16,
            vertical: spacing12,
          ),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusMedium),
          textStyle: lightTextTheme.labelLarge,
        ),
      ),

      // Floating action button theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryMint,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryMint,
        unselectedItemColor: neutral500,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: lightTextTheme.labelSmall,
        unselectedLabelStyle: lightTextTheme.labelSmall,
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: neutral100,
        selectedColor: primaryMint.withValues(alpha: 0.15),
        disabledColor: neutral200,
        labelStyle: lightTextTheme.labelMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: spacing12,
          vertical: spacing8,
        ),
        shape: RoundedRectangleBorder(borderRadius: borderRadiusSmall),
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 24,
        shape: RoundedRectangleBorder(borderRadius: borderRadiusLarge),
        titleTextStyle: lightTextTheme.headlineSmall,
        contentTextStyle: lightTextTheme.bodyMedium,
      ),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: neutral900,
        contentTextStyle: lightTextTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: borderRadiusMedium),
        behavior: SnackBarBehavior.floating,
      ),

      // Divider theme
      dividerTheme: DividerThemeData(color: neutral200, thickness: 1, space: 1),

      // Icon theme
      iconTheme: IconThemeData(color: neutral700, size: 24),
    );
  }

  // ============================================
  // DARK THEME
  // ============================================

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color scheme
      colorScheme: ColorScheme.dark(
        primary: primaryMint,
        onPrimary: Colors.white,
        primaryContainer: primaryMint.withValues(alpha: 0.2),
        onPrimaryContainer: primaryMint.withValues(alpha: 0.9),

        secondary: accentPink,
        onSecondary: Colors.white,
        secondaryContainer: accentPink.withValues(alpha: 0.2),
        onSecondaryContainer: accentPink,

        tertiary: accentTeal,
        onTertiary: Colors.white,
        tertiaryContainer: accentTeal.withValues(alpha: 0.2),
        onTertiaryContainer: accentTeal,

        error: error,
        onError: Colors.white,
        errorContainer: error.withValues(alpha: 0.2),
        onErrorContainer: error,

        surface: neutral900,
        onSurface: neutral50,
        surfaceContainerHighest: neutral800,
        onSurfaceVariant: neutral300,

        outline: neutral600,
        outlineVariant: neutral700,

        shadow: Colors.black.withValues(alpha: 0.3),
        scrim: Colors.black.withValues(alpha: 0.7),

        inverseSurface: neutral100,
        onInverseSurface: neutral900,
        inversePrimary: primaryDark,
      ),

      // Typography
      textTheme: darkTextTheme,

      // App bar theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: neutral900,
        foregroundColor: neutral50,
        titleTextStyle: darkTextTheme.titleLarge,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 0,
        color: neutral800,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadiusMedium,
          side: BorderSide(color: neutral700, width: 1),
        ),
        margin: const EdgeInsets.all(0),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: neutral800,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacing16,
          vertical: spacing16,
        ),
        border: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: BorderSide(color: neutral600, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: BorderSide(color: neutral600, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: const BorderSide(color: primaryMint, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: const BorderSide(color: error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: const BorderSide(color: error, width: 2),
        ),
        labelStyle: darkTextTheme.bodyMedium?.copyWith(color: neutral400),
        hintStyle: darkTextTheme.bodyMedium?.copyWith(color: neutral500),
      ),

      // Button themes
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryMint,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing24,
            vertical: spacing16,
          ),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusMedium),
          elevation: 0,
          textStyle: darkTextTheme.labelLarge,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neutral800,
          foregroundColor: primaryMint,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing24,
            vertical: spacing16,
          ),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusMedium),
          elevation: 0,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          textStyle: darkTextTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryMint,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing24,
            vertical: spacing16,
          ),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusMedium),
          side: BorderSide(color: neutral600, width: 1),
          textStyle: darkTextTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryMint,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing16,
            vertical: spacing12,
          ),
          shape: RoundedRectangleBorder(borderRadius: borderRadiusMedium),
          textStyle: darkTextTheme.labelLarge,
        ),
      ),

      // Floating action button theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryMint,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: neutral800,
        selectedItemColor: primaryMint,
        unselectedItemColor: neutral500,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: darkTextTheme.labelSmall,
        unselectedLabelStyle: darkTextTheme.labelSmall,
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: neutral800,
        selectedColor: primaryMint.withValues(alpha: 0.3),
        disabledColor: neutral700,
        labelStyle: darkTextTheme.labelMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: spacing12,
          vertical: spacing8,
        ),
        shape: RoundedRectangleBorder(borderRadius: borderRadiusSmall),
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: neutral800,
        elevation: 24,
        shape: RoundedRectangleBorder(borderRadius: borderRadiusLarge),
        titleTextStyle: darkTextTheme.headlineSmall,
        contentTextStyle: darkTextTheme.bodyMedium,
      ),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: neutral800,
        contentTextStyle: darkTextTheme.bodyMedium?.copyWith(color: neutral50),
        shape: RoundedRectangleBorder(borderRadius: borderRadiusMedium),
        behavior: SnackBarBehavior.floating,
      ),

      // Divider theme
      dividerTheme: DividerThemeData(color: neutral700, thickness: 1, space: 1),

      // Icon theme
      iconTheme: IconThemeData(color: neutral300, size: 24),
    );
  }
}
