import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
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

  ImportResult({
    required this.successCount,
    required this.failureCount,
    required this.duplicateCount,
    required this.importedExpenses,
    required this.importedCategories,
    required this.categoriesImported,
    required this.categoriesSkipped,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccessful => successCount > 0 || categoriesImported > 0;
  int get totalProcessed => successCount + failureCount + duplicateCount;
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

  /// Import expenses from CSV file
  /// NOTE: CSV import only handles expenses, not categories.
  /// Categories must exist in the app before importing.
  static Future<ImportResult> importFromCSV(
    String filePath,
    String userId,
    List<Expense> existingExpenses,
    List<QuickCategory> availableCategories,
  ) async {
    debugPrint('📥 [ImportService] Importing from CSV: $filePath');

    final errors = <String>[];
    final importedExpenses = <Expense>[];
    int successCount = 0;
    int failureCount = 0;
    int duplicateCount = 0;

    try {
      // Read file
      final file = File(filePath);
      final csvString = await file.readAsString();

      // Parse CSV
      final csvData = const CsvToListConverter().convert(csvString);

      if (csvData.isEmpty) {
        errors.add('CSV file is empty');
        return ImportResult(
          successCount: 0,
          failureCount: 0,
          duplicateCount: 0,
          importedExpenses: [],
          importedCategories: [],
          categoriesImported: 0,
          categoriesSkipped: 0,
          errors: errors,
        );
      }

      // Get header row
      final header = csvData.first.map((e) => e.toString()).toList();
      debugPrint('📋 [ImportService] CSV header: $header');

      // Validate header
      final requiredFields = ['Amount', 'Description', 'Category', 'Date'];
      for (final field in requiredFields) {
        if (!header.contains(field)) {
          errors.add('Missing required field: $field');
          return ImportResult(
            successCount: 0,
            failureCount: 0,
            duplicateCount: 0,
            importedExpenses: [],
            importedCategories: [],
            categoriesImported: 0,
            categoriesSkipped: 0,
            errors: errors,
          );
        }
      }

      // Get column indices
      final idIndex = header.indexOf('ID');
      final typeIndex = header.indexOf('Type');
      final amountIndex = header.indexOf('Amount');
      final descIndex = header.indexOf('Description');
      final categoryIndex = header.indexOf('Category');
      final dateIndex = header.indexOf('Date');
      final languageIndex = header.indexOf('Language');
      final rawInputIndex = header.indexOf('Raw Input');
      final confidenceIndex = header.indexOf('Confidence');

      // Process data rows (skip header)
      for (int i = 1; i < csvData.length; i++) {
        try {
          final row = csvData[i];

          // Extract fields
          final id = idIndex >= 0 && row.length > idIndex
              ? row[idIndex].toString()
              : const Uuid().v4();

          // Check for duplicates
          if (existingExpenses.any((e) => e.id == id)) {
            debugPrint(
              '⚠️ [ImportService] Duplicate ID found: $id (row ${i + 1})',
            );
            duplicateCount++;
            continue;
          }

          final typeStr = typeIndex >= 0 && row.length > typeIndex
              ? row[typeIndex].toString()
              : 'expense';
          final amount = (row[amountIndex] as num).toDouble();
          final description = row[descIndex].toString();
          final categoryId = row[categoryIndex].toString();
          final dateStr = row[dateIndex].toString();
          final language = languageIndex >= 0 && row.length > languageIndex
              ? row[languageIndex].toString()
              : 'en';
          final rawInput = rawInputIndex >= 0 && row.length > rawInputIndex
              ? row[rawInputIndex].toString()
              : '';
          final confidence =
              confidenceIndex >= 0 && row.length > confidenceIndex
              ? (row[confidenceIndex] as num).toDouble()
              : 1.0;

          // Validate required fields
          if (amount <= 0) {
            errors.add('Row ${i + 1}: Invalid amount ($amount)');
            failureCount++;
            continue;
          }

          if (description.isEmpty) {
            errors.add('Row ${i + 1}: Missing description');
            failureCount++;
            continue;
          }

          // Parse date
          DateTime date;
          try {
            date = DateTime.parse(dateStr);
          } catch (e) {
            errors.add('Row ${i + 1}: Invalid date format ($dateStr)');
            failureCount++;
            continue;
          }

          // Parse transaction type
          final type = TransactionType.fromJson(typeStr);

          // Validate and fix category ID if it doesn't exist
          final validCategoryId = _validateCategoryId(
            categoryId,
            type,
            availableCategories,
          );

          // Create expense
          final expense = Expense(
            id: id,
            amount: amount,
            description: description,
            categoryId: validCategoryId,
            language: language,
            date: date,
            userId: userId,
            rawInput: rawInput,
            confidence: confidence,
            type: type,
          );

          importedExpenses.add(expense);
          successCount++;
          debugPrint('✅ [ImportService] Imported: $description ($amount)');
        } catch (e) {
          errors.add('Row ${i + 1}: $e');
          failureCount++;
          debugPrint('❌ [ImportService] Error in row ${i + 1}: $e');
        }
      }

      debugPrint(
        '✅ [ImportService] Import complete: $successCount success, $failureCount failed, $duplicateCount duplicates',
      );

      return ImportResult(
        successCount: successCount,
        failureCount: failureCount,
        duplicateCount: duplicateCount,
        importedExpenses: importedExpenses,
        importedCategories: [],
        categoriesImported: 0,
        categoriesSkipped: 0,
        errors: errors,
      );
    } catch (e) {
      debugPrint('❌ [ImportService] Error importing CSV: $e');
      errors.add('Failed to import CSV: $e');
      return ImportResult(
        successCount: successCount,
        failureCount: failureCount,
        duplicateCount: duplicateCount,
        importedExpenses: importedExpenses,
        importedCategories: [],
        categoriesImported: 0,
        categoriesSkipped: 0,
        errors: errors,
      );
    }
  }

  /// Import expenses and categories from JSON file
  /// Handles v1.0 (expenses only), v2.0 (with userCategories), and v3.0 (with full categories)
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

    try {
      // Read file
      final file = File(filePath);
      final jsonString = await file.readAsString();

      // Parse JSON
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      // Check version
      final version = jsonData['version'] as String? ?? '1.0';
      debugPrint('📋 [ImportService] Import file version: $version');

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
      );
    }
  }
}
