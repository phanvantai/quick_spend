import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense.dart';
import '../models/category.dart';

/// Service for exporting expense data to various formats
class ExportService {
  /// Export expenses to CSV format
  /// NOTE: CSV export only includes expenses, not categories.
  /// For complete backup with categories, use JSON export.
  /// Returns the file path of the exported CSV file
  static Future<String> exportToCSV(List<Expense> expenses) async {
    debugPrint('📤 [ExportService] Exporting ${expenses.length} expenses to CSV');

    try {
      // Create CSV data
      final List<List<dynamic>> csvData = [
        // Header row
        [
          'ID',
          'Type',
          'Amount',
          'Description',
          'Category',
          'Date',
          'Language',
          'Raw Input',
          'Confidence',
        ],
        // Data rows
        ...expenses.map((expense) => [
              expense.id,
              expense.type.name,
              expense.amount,
              expense.description,
              expense.categoryId,
              expense.date.toIso8601String(),
              expense.language,
              expense.rawInput,
              expense.confidence,
            ]),
      ];

      // Convert to CSV string
      final csvString = const ListToCsvConverter().convert(csvData);

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/quick_spend_export_$timestamp.csv';
      final file = File(filePath);
      await file.writeAsString(csvString);

      debugPrint('✅ [ExportService] CSV export saved to: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('❌ [ExportService] Error exporting to CSV: $e');
      rethrow;
    }
  }

  /// Export expenses and categories to JSON format
  /// Includes FULL category info for ALL categories (system + user)
  /// This ensures complete portability and preserves customizations
  /// Returns the file path of the exported JSON file
  static Future<String> exportToJSON(
    List<Expense> expenses,
    List<QuickCategory> categories,
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
        'version': '3.0', // Updated version to include full category info
        'exportDate': DateTime.now().toIso8601String(),
        'totalExpenses': expenses.length,
        'totalCategories': categoryMap.length,
        // Full category definitions (includes system + user categories)
        'categories': categoryMap,
        'expenses': expenses.map((e) => e.toJson()).toList(),
      };

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
  static Future<void> shareFile(String filePath, String fileName) async {
    debugPrint('📤 [ExportService] Sharing file: $filePath');

    try {
      final file = XFile(filePath);
      await Share.shareXFiles(
        [file],
        subject: 'Quick Spend Export',
        text: 'My expense data from Quick Spend',
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
