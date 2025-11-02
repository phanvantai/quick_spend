import 'package:cloud_firestore/cloud_firestore.dart';
import 'category.dart';

/// Expense model representing a single expense entry
class Expense {
  final String id;
  final double amount;
  final String description;
  final ExpenseCategory category;
  final String language; // 'en' or 'vi'
  final DateTime date;
  final String userId;
  final String rawInput; // Original input from user
  final double confidence; // Confidence score of auto-categorization (0-1)

  Expense({
    required this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.language,
    required this.date,
    required this.userId,
    required this.rawInput,
    this.confidence = 1.0,
  });

  /// Create Expense from Firestore document
  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      amount: (data['amount'] as num).toDouble(),
      description: data['description'] as String,
      category: ExpenseCategory.values.firstWhere(
        (e) => e.toString() == 'ExpenseCategory.${data['category']}',
        orElse: () => ExpenseCategory.other,
      ),
      language: data['language'] as String? ?? 'en',
      date: (data['date'] as Timestamp).toDate(),
      userId: data['userId'] as String,
      rawInput: data['rawInput'] as String? ?? '',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Convert Expense to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'description': description,
      'category': category.toString().split('.').last,
      'language': language,
      'date': Timestamp.fromDate(date),
      'userId': userId,
      'rawInput': rawInput,
      'confidence': confidence,
    };
  }

  /// Convert Expense to JSON for local storage (SQLite)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'category': category.toString().split('.').last,
      'language': language,
      'date': date.toIso8601String(),
      'userId': userId,
      'rawInput': rawInput,
      'confidence': confidence,
    };
  }

  /// Create Expense from JSON (SQLite)
  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      category: ExpenseCategory.values.firstWhere(
        (e) => e.toString() == 'ExpenseCategory.${json['category']}',
        orElse: () => ExpenseCategory.other,
      ),
      language: json['language'] as String? ?? 'en',
      date: DateTime.parse(json['date'] as String),
      userId: json['userId'] as String,
      rawInput: json['rawInput'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Create a copy with modified fields
  Expense copyWith({
    String? id,
    double? amount,
    String? description,
    ExpenseCategory? category,
    String? language,
    DateTime? date,
    String? userId,
    String? rawInput,
    double? confidence,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      language: language ?? this.language,
      date: date ?? this.date,
      userId: userId ?? this.userId,
      rawInput: rawInput ?? this.rawInput,
      confidence: confidence ?? this.confidence,
    );
  }

  /// Get formatted amount string
  String getFormattedAmount({bool includeCurrency = true}) {
    if (language == 'vi') {
      // Vietnamese format
      final formatted = amount.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
      return includeCurrency ? '$formatted đ' : formatted;
    } else {
      // English format
      final formatted = amount.toStringAsFixed(2).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
      return includeCurrency ? '\$$formatted' : formatted;
    }
  }

  @override
  String toString() {
    return 'Expense(id: $id, amount: $amount, description: $description, category: $category, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Expense &&
        other.id == id &&
        other.amount == amount &&
        other.description == description &&
        other.category == category &&
        other.language == language &&
        other.date == date &&
        other.userId == userId &&
        other.rawInput == rawInput &&
        other.confidence == confidence;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      amount,
      description,
      category,
      language,
      date,
      userId,
      rawInput,
      confidence,
    );
  }
}
