import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';

/// Transaction type enum
enum TransactionType {
  expense,
  income;

  /// Convert to string for storage
  String toJson() => name;

  /// Create from string
  static TransactionType fromJson(String value) {
    return TransactionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TransactionType.expense,
    );
  }
}

/// Expense model representing a single expense or income entry
/// Note: Named "Expense" for backward compatibility, but supports both types
class Expense {
  final String id;
  final double amount;
  final String description;
  final String categoryId; // Category ID instead of enum
  final String language; // 'en' or 'vi'
  final DateTime date;
  final String userId;
  final String rawInput; // Original input from user
  final double confidence; // Confidence score of auto-categorization (0-1)
  final TransactionType type; // Transaction type (expense or income)

  Expense({
    required this.id,
    required this.amount,
    required this.description,
    required this.categoryId,
    required this.language,
    required this.date,
    required this.userId,
    required this.rawInput,
    this.confidence = 1.0,
    this.type = TransactionType.expense, // Default to expense for backward compatibility
  });

  /// Create Expense from Firestore document
  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      amount: (data['amount'] as num).toDouble(),
      description: data['description'] as String,
      categoryId:
          data['categoryId'] as String? ??
          data['category'] as String? ??
          'other',
      language: data['language'] as String? ?? 'en',
      date: (data['date'] as Timestamp).toDate(),
      userId: data['userId'] as String,
      rawInput: data['rawInput'] as String? ?? '',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 1.0,
      type: TransactionType.fromJson(data['type'] as String? ?? 'expense'),
    );
  }

  /// Convert Expense to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'description': description,
      'categoryId': categoryId,
      'language': language,
      'date': Timestamp.fromDate(date),
      'userId': userId,
      'rawInput': rawInput,
      'confidence': confidence,
      'type': type.toJson(),
    };
  }

  /// Convert Expense to JSON for local storage (SQLite)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'categoryId': categoryId,
      'language': language,
      'date': date.toIso8601String(),
      'userId': userId,
      'rawInput': rawInput,
      'confidence': confidence,
      'type': type.toJson(),
    };
  }

  /// Create Expense from JSON (SQLite)
  factory Expense.fromJson(Map<String, dynamic> json) {
    // Handle migration from old 'category' field to new 'categoryId'
    String catId =
        json['categoryId'] as String? ?? json['category'] as String? ?? 'other';

    return Expense(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      categoryId: catId,
      language: json['language'] as String? ?? 'en',
      date: DateTime.parse(json['date'] as String),
      userId: json['userId'] as String,
      rawInput: json['rawInput'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      type: TransactionType.fromJson(json['type'] as String? ?? 'expense'),
    );
  }

  /// Create a copy with modified fields
  Expense copyWith({
    String? id,
    double? amount,
    String? description,
    String? categoryId,
    String? language,
    DateTime? date,
    String? userId,
    String? rawInput,
    double? confidence,
    TransactionType? type,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      language: language ?? this.language,
      date: date ?? this.date,
      userId: userId ?? this.userId,
      rawInput: rawInput ?? this.rawInput,
      confidence: confidence ?? this.confidence,
      type: type ?? this.type,
    );
  }

  /// Get formatted amount string
  String getFormattedAmount({bool includeCurrency = true}) {
    final formatted = toCurrencyString(
      amount.toString(),
      mantissaLength: language == 'vi' ? 0 : 2,
      thousandSeparator: language.startsWith('vi')
          ? ThousandSeparator.Period
          : ThousandSeparator.Comma,
    );

    if (!includeCurrency) {
      return formatted;
    }

    return language == 'vi' ? '$formatted đ' : '\$$formatted';
  }

  /// Check if this is an income transaction
  bool get isIncome => type == TransactionType.income;

  /// Check if this is an expense transaction
  bool get isExpense => type == TransactionType.expense;

  @override
  String toString() {
    return 'Expense(id: $id, amount: $amount, description: $description, categoryId: $categoryId, type: ${type.name}, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Expense &&
        other.id == id &&
        other.amount == amount &&
        other.description == description &&
        other.categoryId == categoryId &&
        other.language == language &&
        other.date == date &&
        other.userId == userId &&
        other.rawInput == rawInput &&
        other.confidence == confidence &&
        other.type == type;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      amount,
      description,
      categoryId,
      language,
      date,
      userId,
      rawInput,
      confidence,
      type,
    );
  }
}
