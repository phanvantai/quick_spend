import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';

/// Result of an import operation
class ImportResult {
  final int successCount;
  final int failureCount;
  final int duplicateCount;
  final List<Expense> importedExpenses;
  final List<String> errors;

  ImportResult({
    required this.successCount,
    required this.failureCount,
    required this.duplicateCount,
    required this.importedExpenses,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccessful => successCount > 0;
  int get totalProcessed => successCount + failureCount + duplicateCount;
}

/// Service for importing expense data from various formats
class ImportService {
  /// Import expenses from CSV file
  static Future<ImportResult> importFromCSV(
    String filePath,
    String userId,
    List<Expense> existingExpenses,
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
            debugPrint('⚠️ [ImportService] Duplicate ID found: $id (row ${i + 1})');
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

          // Create expense
          final expense = Expense(
            id: id,
            amount: amount,
            description: description,
            categoryId: categoryId,
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
        errors: errors,
      );
    }
  }

  /// Import expenses from JSON file
  static Future<ImportResult> importFromJSON(
    String filePath,
    String userId,
    List<Expense> existingExpenses,
  ) async {
    debugPrint('📥 [ImportService] Importing from JSON: $filePath');

    final errors = <String>[];
    final importedExpenses = <Expense>[];
    int successCount = 0;
    int failureCount = 0;
    int duplicateCount = 0;

    try {
      // Read file
      final file = File(filePath);
      final jsonString = await file.readAsString();

      // Parse JSON
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      // Validate structure
      if (!jsonData.containsKey('expenses')) {
        errors.add('Invalid JSON structure: missing "expenses" key');
        return ImportResult(
          successCount: 0,
          failureCount: 0,
          duplicateCount: 0,
          importedExpenses: [],
          errors: errors,
        );
      }

      final expenses = jsonData['expenses'] as List<dynamic>;
      debugPrint('📋 [ImportService] Found ${expenses.length} expenses in JSON');

      // Process expenses
      for (int i = 0; i < expenses.length; i++) {
        try {
          final expenseData = expenses[i] as Map<String, dynamic>;

          // Check for duplicates
          final id = expenseData['id'] as String?;
          if (id != null && existingExpenses.any((e) => e.id == id)) {
            debugPrint('⚠️ [ImportService] Duplicate ID found: $id (item ${i + 1})');
            duplicateCount++;
            continue;
          }

          // Create expense from JSON (with fallback to new ID)
          final expense = Expense.fromJson({
            ...expenseData,
            'id': id ?? const Uuid().v4(),
            'userId': userId, // Override userId to current user
          });

          // Validate
          if (expense.amount <= 0) {
            errors.add('Item ${i + 1}: Invalid amount (${expense.amount})');
            failureCount++;
            continue;
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
        '✅ [ImportService] Import complete: $successCount success, $failureCount failed, $duplicateCount duplicates',
      );

      return ImportResult(
        successCount: successCount,
        failureCount: failureCount,
        duplicateCount: duplicateCount,
        importedExpenses: importedExpenses,
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
        errors: errors,
      );
    }
  }
}
