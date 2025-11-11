import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../models/recurring_expense_template.dart';
import '../models/recurrence_pattern.dart';
import 'expense_service.dart';
import 'recurring_template_service.dart';
import 'package:uuid/uuid.dart';

/// Service for generating expenses from recurring templates
class RecurringExpenseService {
  final ExpenseService _expenseService;
  final RecurringTemplateService _templateService;
  final _uuid = const Uuid();

  RecurringExpenseService(this._expenseService, this._templateService);

  /// Generate all pending recurring expenses for a user
  /// This should be called when the app starts
  Future<int> generatePendingExpenses(String userId) async {
    debugPrint('🔄 [RecurringExpenseService] Generating pending recurring expenses...');

    final templates = await _templateService.getActiveTemplates(userId);
    int generatedCount = 0;

    for (final template in templates) {
      final count = await _generateExpensesForTemplate(template);
      generatedCount += count;
    }

    debugPrint('✅ [RecurringExpenseService] Generated $generatedCount recurring expense(s)');
    return generatedCount;
  }

  /// Generate expenses for a specific recurring template
  Future<int> _generateExpensesForTemplate(RecurringExpenseTemplate template) async {
    if (template.pattern == RecurrencePattern.none) {
      debugPrint('⚠️ [RecurringExpenseService] Template has no recurrence pattern: ${template.id}');
      return 0;
    }

    if (!template.isActive) {
      debugPrint('⏸️ [RecurringExpenseService] Template is inactive: ${template.id}');
      return 0;
    }

    final now = DateTime.now();
    final startDate = template.lastGeneratedDate ?? template.startDate;
    final endDate = template.endDate ?? now;

    // Don't generate if we've reached the end date
    if (template.endDate != null && now.isAfter(template.endDate!)) {
      debugPrint('⏭️ [RecurringExpenseService] Template ${template.id} has ended');
      return 0;
    }

    final datesToGenerate = _calculateDatesToGenerate(
      startDate: startDate,
      endDate: endDate,
      pattern: template.pattern,
      now: now,
    );

    int generatedCount = 0;
    DateTime? lastGenerated;

    for (final date in datesToGenerate) {
      // Generate new expense (normal expense, not template)
      final expense = Expense(
        id: _uuid.v4(),
        amount: template.amount,
        description: template.description,
        categoryId: template.categoryId,
        language: template.language,
        date: date,
        userId: template.userId,
        rawInput: 'Recurring: ${template.description}',
        confidence: 1.0,
        type: template.type,
      );

      await _expenseService.saveExpense(expense);
      generatedCount++;
      lastGenerated = date;

      debugPrint('💾 [RecurringExpenseService] Generated expense for ${template.description} on $date');
    }

    // Update the template's last generated date
    if (lastGenerated != null) {
      await _templateService.updateLastGeneratedDate(template.id, lastGenerated);
    }

    return generatedCount;
  }

  /// Calculate which dates need recurring expenses generated
  List<DateTime> _calculateDatesToGenerate({
    required DateTime startDate,
    required DateTime endDate,
    required RecurrencePattern pattern,
    required DateTime now,
  }) {
    final dates = <DateTime>[];
    DateTime current = _getNextOccurrence(startDate, pattern);

    // Generate up to the current date (don't generate future dates)
    final generateUntil = endDate.isBefore(now) ? endDate : now;

    while (current.isBefore(generateUntil) || _isSameDay(current, generateUntil)) {
      // Don't generate if it's in the future
      if (current.isAfter(now)) break;

      // Don't generate if it's before the start date
      if (current.isBefore(startDate)) {
        current = _getNextOccurrence(current, pattern);
        continue;
      }

      dates.add(current);
      current = _getNextOccurrence(current, pattern);

      // Safety limit: don't generate more than 100 instances at once
      if (dates.length >= 100) {
        debugPrint('⚠️ [RecurringExpenseService] Hit safety limit of 100 instances');
        break;
      }
    }

    return dates;
  }

  /// Get the next occurrence date based on the pattern
  DateTime _getNextOccurrence(DateTime current, RecurrencePattern pattern) {
    switch (pattern) {
      case RecurrencePattern.monthly:
        // Add one month
        return DateTime(
          current.year,
          current.month + 1,
          current.day,
          current.hour,
          current.minute,
          current.second,
        );

      case RecurrencePattern.yearly:
        // Add one year
        return DateTime(
          current.year + 1,
          current.month,
          current.day,
          current.hour,
          current.minute,
          current.second,
        );

      case RecurrencePattern.none:
        return current;
    }
  }

  /// Check if two dates are on the same day (ignoring time)
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Preview how many instances would be generated for a template
  Future<List<DateTime>> previewRecurringDates({
    required DateTime startDate,
    required RecurrencePattern pattern,
    DateTime? endDate,
    int maxCount = 12, // Preview up to 12 occurrences
  }) async {
    if (pattern == RecurrencePattern.none) {
      return [];
    }

    final dates = <DateTime>[];
    DateTime current = startDate;
    final now = DateTime.now();
    final actualEndDate = endDate ?? DateTime(now.year + 10, now.month, now.day);

    for (int i = 0; i < maxCount; i++) {
      if (current.isAfter(actualEndDate)) break;

      dates.add(current);
      current = _getNextOccurrence(current, pattern);
    }

    return dates;
  }
}
