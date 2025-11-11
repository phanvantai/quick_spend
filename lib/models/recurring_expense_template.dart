import 'package:intl/intl.dart';
import 'expense.dart';
import 'recurrence_pattern.dart';

/// Recurring expense template model
/// This represents a configuration for generating recurring expenses
/// Separate from Expense - this is just a template/config
class RecurringExpenseTemplate {
  final String id;
  final double amount;
  final String description;
  final String categoryId;
  final String language;
  final String userId;
  final TransactionType type;
  final RecurrencePattern pattern; // monthly/yearly
  final DateTime startDate; // When to start generating
  final DateTime? endDate; // When to stop (null = forever)
  final DateTime? lastGeneratedDate; // Track generation progress
  final bool isActive; // Can be paused without deleting

  RecurringExpenseTemplate({
    required this.id,
    required this.amount,
    required this.description,
    required this.categoryId,
    required this.language,
    required this.userId,
    required this.type,
    required this.pattern,
    required this.startDate,
    this.endDate,
    this.lastGeneratedDate,
    this.isActive = true,
  });

  /// Convert to JSON for SQLite storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'categoryId': categoryId,
      'language': language,
      'userId': userId,
      'type': type.toJson(),
      'pattern': pattern.toJson(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'lastGeneratedDate': lastGeneratedDate?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
    };
  }

  /// Create from JSON (SQLite)
  factory RecurringExpenseTemplate.fromJson(Map<String, dynamic> json) {
    return RecurringExpenseTemplate(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      categoryId: json['categoryId'] as String,
      language: json['language'] as String,
      userId: json['userId'] as String,
      type: TransactionType.fromJson(json['type'] as String),
      pattern: RecurrencePattern.fromJson(json['pattern'] as String),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      lastGeneratedDate: json['lastGeneratedDate'] != null ? DateTime.parse(json['lastGeneratedDate'] as String) : null,
      isActive: (json['isActive'] as int) == 1,
    );
  }

  /// Create a copy with modified fields
  RecurringExpenseTemplate copyWith({
    String? id,
    double? amount,
    String? description,
    String? categoryId,
    String? language,
    String? userId,
    TransactionType? type,
    RecurrencePattern? pattern,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? lastGeneratedDate,
    bool? isActive,
    bool clearEndDate = false,
    bool clearLastGeneratedDate = false,
  }) {
    return RecurringExpenseTemplate(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      language: language ?? this.language,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      pattern: pattern ?? this.pattern,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      lastGeneratedDate: clearLastGeneratedDate ? null : (lastGeneratedDate ?? this.lastGeneratedDate),
      isActive: isActive ?? this.isActive,
    );
  }

  /// Get formatted amount string
  /// Note: This method doesn't have access to currency, so it uses language as a proxy
  /// For proper currency-based formatting, use the widgets which have access to currency
  String getFormattedAmount({bool includeCurrency = true, String? currency}) {
    String formatted;

    // Use currency if provided, otherwise assume based on language
    final useDecimals = currency != null
        ? (currency != 'VND')
        : !language.startsWith('vi');

    if (language.startsWith('vi')) {
      // Vietnamese format: use period as thousand separator
      final formatter = NumberFormat(useDecimals ? '#,##0.00' : '#,##0', 'en_US');
      formatted = formatter.format(amount).replaceAll(',', '.');
    } else {
      // English format: use comma as thousand separator
      final formatter = NumberFormat(useDecimals ? '#,##0.00' : '#,##0', 'en_US');
      formatted = formatter.format(amount);
    }

    if (!includeCurrency) {
      return formatted;
    }

    return language.startsWith('vi') ? '$formatted đ' : '\$$formatted';
  }

  @override
  String toString() {
    return 'RecurringExpenseTemplate(id: $id, description: $description, amount: $amount, pattern: ${pattern.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RecurringExpenseTemplate &&
        other.id == id &&
        other.amount == amount &&
        other.description == description &&
        other.categoryId == categoryId &&
        other.language == language &&
        other.userId == userId &&
        other.type == type &&
        other.pattern == pattern &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.lastGeneratedDate == lastGeneratedDate &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      amount,
      description,
      categoryId,
      language,
      userId,
      type,
      pattern,
      startDate,
      endDate,
      lastGeneratedDate,
      isActive,
    );
  }
}
