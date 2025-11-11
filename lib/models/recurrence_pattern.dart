/// Recurrence pattern for recurring expenses
enum RecurrencePattern {
  /// No recurrence - one-time expense
  none,

  /// Recurs every month on the same day
  monthly,

  /// Recurs every year on the same date
  yearly;

  /// Convert to string for storage
  String toJson() => name;

  /// Create from string
  static RecurrencePattern fromJson(String value) {
    return RecurrencePattern.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RecurrencePattern.none,
    );
  }

  /// Get human-readable description
  String getDescription(String language) {
    switch (this) {
      case RecurrencePattern.none:
        return language == 'vi' ? 'Không lặp lại' : 'No recurrence';
      case RecurrencePattern.monthly:
        return language == 'vi' ? 'Hàng tháng' : 'Monthly';
      case RecurrencePattern.yearly:
        return language == 'vi' ? 'Hàng năm' : 'Yearly';
    }
  }

  /// Check if this is a recurring pattern
  bool get isRecurring => this != RecurrencePattern.none;
}
