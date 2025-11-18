import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/app_config.dart';

/// Service for exporting expense data to JSON format
class ExportService {
  /// Export expenses and categories to JSON format
  /// Includes FULL category info for ALL categories (system + user)
  /// Also includes app settings (language, currency) for complete backup
  /// This ensures complete portability and preserves customizations
  /// Returns the file path of the exported JSON file
  static Future<String> exportToJSON(
    List<Expense> expenses,
    List<QuickCategory> categories,
    AppConfig appConfig,
  ) async {
    debugPrint(
      '📤 [ExportService] Exporting ${expenses.length} expenses and ${categories.length} categories to JSON',
    );

    try {
      // Create category map with FULL info for ALL categories (not just used ones)
      final categoryMap = <String, Map<String, dynamic>>{};
      for (final category in categories) {
        categoryMap[category.id] = category.toJson();
      }

      final systemCount = categories.where((c) => c.isSystem).length;
      final userCount = categories.where((c) => !c.isSystem).length;
      debugPrint(
        '📤 [ExportService] Exporting ${categoryMap.length} categories ($systemCount system, $userCount user)',
      );

      // Create JSON structure
      final jsonData = {
        'version': '4.0', // Updated version to include app settings
        'exportDate': DateTime.now().toIso8601String(),
        'totalExpenses': expenses.length,
        'totalCategories': categoryMap.length,
        // App settings (language and currency)
        'settings': {
          'language': appConfig.language,
          'currency': appConfig.currency,
        },
        // Full category definitions (includes system + user categories)
        'categories': categoryMap,
        'expenses': expenses.map((e) => e.toJson()).toList(),
      };

      debugPrint(
        '📤 [ExportService] Including app settings: language=${appConfig.language}, currency=${appConfig.currency}',
      );

      // Convert to JSON string with pretty formatting
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/quick_spend_export_$timestamp.json';
      final file = File(filePath);
      await file.writeAsString(jsonString);

      debugPrint('✅ [ExportService] JSON export saved to: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('❌ [ExportService] Error exporting to JSON: $e');
      rethrow;
    }
  }

  /// Share exported file using the share dialog
  /// [sharePositionOrigin] is required for iOS to position the share popover
  /// [subject] and [text] should be localized strings
  static Future<void> shareFile(
    String filePath,
    String fileName, {
    required String subject,
    required String text,
    Rect? sharePositionOrigin,
  }) async {
    debugPrint('📤 [ExportService] Sharing file: $filePath');

    try {
      final file = XFile(filePath);
      await Share.shareXFiles(
        [file],
        subject: subject,
        text: text,
        sharePositionOrigin: sharePositionOrigin,
      );

      debugPrint('✅ [ExportService] File shared successfully');
    } catch (e) {
      debugPrint('❌ [ExportService] Error sharing file: $e');
      rethrow;
    }
  }

  /// Get export summary statistics
  static Map<String, dynamic> getExportSummary(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return {
        'totalExpenses': 0,
        'totalIncome': 0,
        'totalAmount': 0.0,
        'totalIncomeAmount': 0.0,
        'dateRange': null,
      };
    }

    final expenseList = expenses.where((e) => e.isExpense).toList();
    final incomeList = expenses.where((e) => e.isIncome).toList();

    final sortedByDate = List<Expense>.from(expenses)
      ..sort((a, b) => a.date.compareTo(b.date));

    return {
      'totalExpenses': expenseList.length,
      'totalIncome': incomeList.length,
      'totalAmount': expenseList.fold<double>(
        0.0,
        (sum, e) => sum + e.amount,
      ),
      'totalIncomeAmount': incomeList.fold<double>(
        0.0,
        (sum, e) => sum + e.amount,
      ),
      'dateRange': {
        'start': sortedByDate.first.date,
        'end': sortedByDate.last.date,
      },
    };
  }
}
