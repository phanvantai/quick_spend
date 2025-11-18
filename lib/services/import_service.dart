import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../models/category.dart';

/// Result of an import operation
class ImportResult {
  final int successCount;
  final int failureCount;
  final int duplicateCount;
  final List<Expense> importedExpenses;
  final List<QuickCategory> importedCategories;
  final int categoriesImported;
  final int categoriesSkipped;
  final List<String> errors;
  final String? language; // Language setting from import file
  final String? currency; // Currency setting from import file

  ImportResult({
    required this.successCount,
    required this.failureCount,
    required this.duplicateCount,
    required this.importedExpenses,
    required this.importedCategories,
    required this.categoriesImported,
    required this.categoriesSkipped,
    required this.errors,
    this.language,
    this.currency,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccessful => successCount > 0 || categoriesImported > 0;
  int get totalProcessed => successCount + failureCount + duplicateCount;
  bool get hasSettings => language != null || currency != null;
}

/// Service for importing expense data from various formats
class ImportService {
  /// Validate and fix category ID
  /// Returns a valid category ID, falling back to "other" or "other_income" if invalid
  static String _validateCategoryId(
    String categoryId,
    TransactionType type,
    List<QuickCategory> availableCategories,
  ) {
    // Check if category exists
    final categoryExists = availableCategories.any((c) => c.id == categoryId);

    if (categoryExists) {
      return categoryId;
    }

    // Category doesn't exist - use fallback
    final fallback = type == TransactionType.income ? 'other_income' : 'other';
    debugPrint(
      '⚠️ [ImportService] Category "$categoryId" not found, using fallback "$fallback"',
    );
    return fallback;
  }

  /// Import expenses and categories from JSON file
  /// Handles v1.0 (expenses only), v2.0 (with userCategories), v3.0 (with full categories), and v4.0 (with settings)
  static Future<ImportResult> importFromJSON(
    String filePath,
    String userId,
    List<Expense> existingExpenses,
    List<QuickCategory> existingCategories,
  ) async {
    debugPrint('📥 [ImportService] Importing from JSON: $filePath');

    final errors = <String>[];
    final importedExpenses = <Expense>[];
    final importedCategories = <QuickCategory>[];
    int successCount = 0;
    int failureCount = 0;
    int duplicateCount = 0;
    int categoriesImported = 0;
    int categoriesSkipped = 0;
    String? importedLanguage;
    String? importedCurrency;

    try {
      // Read file
      final file = File(filePath);
      final jsonString = await file.readAsString();

      // Parse JSON
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      // Check version
      final version = jsonData['version'] as String? ?? '1.0';
      debugPrint('📋 [ImportService] Import file version: $version');

      // Import settings (v4.0+)
      if (jsonData.containsKey('settings')) {
        final settings = jsonData['settings'] as Map<String, dynamic>;
        importedLanguage = settings['language'] as String?;
        importedCurrency = settings['currency'] as String?;
        debugPrint(
          '⚙️ [ImportService] Found settings: language=$importedLanguage, currency=$importedCurrency',
        );
      }

      // Import categories based on version
      if (version == '3.0' && jsonData.containsKey('categories')) {
        // Version 3.0: Full category map with ALL categories
        final categoriesMap = jsonData['categories'] as Map<String, dynamic>;
        debugPrint(
          '📂 [ImportService] Found ${categoriesMap.length} categories to import (v3.0 format)',
        );

        for (final entry in categoriesMap.entries) {
          try {
            //final categoryId = entry.key;
            final categoryData = entry.value as Map<String, dynamic>;

            // Create category from full definition
            // For system categories, preserve isSystem=true but assign to current user
            // For user categories, assign to current user
            final category = QuickCategory.fromJson({
              ...categoryData,
              'userId': categoryData['isSystem'] == 1 ? null : userId,
            });

            // Always add to importedCategories - import file has higher priority
            // Settings screen will handle create vs update
            importedCategories.add(category);
            categoriesImported++;
            debugPrint(
              '✅ [ImportService] Imported category: ${category.name} (${category.isSystem ? "system" : "user"})',
            );
          } catch (e) {
            errors.add('Category "${entry.key}": $e');
            debugPrint('❌ [ImportService] Error importing category: $e');
          }
        }
      } else if (version == '2.0' && jsonData.containsKey('userCategories')) {
        // Version 2.0: User categories list (backward compatibility)
        final userCategoriesData = jsonData['userCategories'] as List<dynamic>;
        debugPrint(
          '📂 [ImportService] Found ${userCategoriesData.length} user categories to import (v2.0 format)',
        );

        for (int i = 0; i < userCategoriesData.length; i++) {
          try {
            final categoryData = userCategoriesData[i] as Map<String, dynamic>;
            final categoryId = categoryData['id'] as String;

            // Check if category already exists
            if (existingCategories.any((c) => c.id == categoryId)) {
              debugPrint(
                '⚠️ [ImportService] Category "$categoryId" already exists, skipping',
              );
              categoriesSkipped++;
              continue;
            }

            // Create category
            final category = QuickCategory.fromJson({
              ...categoryData,
              'userId': userId, // Override userId to current user
            });

            importedCategories.add(category);
            categoriesImported++;
            debugPrint(
              '✅ [ImportService] Imported category: ${category.name}',
            );
          } catch (e) {
            errors.add('Category ${i + 1}: $e');
            debugPrint('❌ [ImportService] Error importing category: $e');
          }
        }
      }

      // Validate structure for expenses
      if (!jsonData.containsKey('expenses')) {
        errors.add('Invalid JSON structure: missing "expenses" key');
        return ImportResult(
          successCount: 0,
          failureCount: 0,
          duplicateCount: 0,
          importedExpenses: [],
          importedCategories: importedCategories,
          categoriesImported: categoriesImported,
          categoriesSkipped: categoriesSkipped,
          errors: errors,
          language: importedLanguage,
          currency: importedCurrency,
        );
      }

      final expenses = jsonData['expenses'] as List<dynamic>;
      debugPrint(
        '📋 [ImportService] Found ${expenses.length} expenses in JSON',
      );

      // Process expenses
      for (int i = 0; i < expenses.length; i++) {
        try {
          final expenseData = expenses[i] as Map<String, dynamic>;

          // Check for duplicates
          final id = expenseData['id'] as String?;
          if (id != null && existingExpenses.any((e) => e.id == id)) {
            debugPrint(
              '⚠️ [ImportService] Duplicate ID found: $id (item ${i + 1})',
            );
            duplicateCount++;
            continue;
          }

          // Create expense from JSON (with fallback to new ID)
          var expense = Expense.fromJson({
            ...expenseData,
            'id': id ?? const Uuid().v4(),
            'userId': userId, // Override userId to current user
          });

          // Validate amount
          if (expense.amount <= 0) {
            errors.add('Item ${i + 1}: Invalid amount (${expense.amount})');
            failureCount++;
            continue;
          }

          // Validate and fix category ID if it doesn't exist
          // This includes all categories: existing + newly imported from this file
          final allAvailableCategories = [
            ...existingCategories,
            ...importedCategories,
          ];
          final validCategoryId = _validateCategoryId(
            expense.categoryId,
            expense.type,
            allAvailableCategories,
          );

          // Update expense with valid category ID if it was changed
          if (validCategoryId != expense.categoryId) {
            expense = expense.copyWith(categoryId: validCategoryId);
          }

          importedExpenses.add(expense);
          successCount++;
          debugPrint(
            '✅ [ImportService] Imported: ${expense.description} (${expense.amount})',
          );
        } catch (e) {
          errors.add('Item ${i + 1}: $e');
          failureCount++;
          debugPrint('❌ [ImportService] Error in item ${i + 1}: $e');
        }
      }

      debugPrint(
        '✅ [ImportService] Import complete: $categoriesImported categories, $successCount expenses imported, $failureCount failed, $duplicateCount duplicates',
      );

      return ImportResult(
        successCount: successCount,
        failureCount: failureCount,
        duplicateCount: duplicateCount,
        importedExpenses: importedExpenses,
        importedCategories: importedCategories,
        categoriesImported: categoriesImported,
        categoriesSkipped: categoriesSkipped,
        errors: errors,
        language: importedLanguage,
        currency: importedCurrency,
      );
    } catch (e) {
      debugPrint('❌ [ImportService] Error importing JSON: $e');
      errors.add('Failed to import JSON: $e');
      return ImportResult(
        successCount: successCount,
        failureCount: failureCount,
        duplicateCount: duplicateCount,
        importedExpenses: importedExpenses,
        importedCategories: importedCategories,
        categoriesImported: categoriesImported,
        categoriesSkipped: categoriesSkipped,
        errors: errors,
        language: importedLanguage,
        currency: importedCurrency,
      );
    }
  }
}
