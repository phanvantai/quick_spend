/// Helper class for date range calculations
class DateRangeHelper {
  /// Get start and end of today
  static DateRange getToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return DateRange(start: start, end: end);
  }

  /// Get start and end of this week (Monday to Sunday)
  static DateRange getThisWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(monday.year, monday.month, monday.day);
    final sunday = monday.add(const Duration(days: 6));
    final end = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);
    return DateRange(start: start, end: end);
  }

  /// Get start and end of this month
  static DateRange getThisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return DateRange(start: start, end: end);
  }

  /// Get start and end of this year
  static DateRange getThisYear() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year, 12, 31, 23, 59, 59);
    return DateRange(start: start, end: end);
  }

  /// Get start and end of last 7 days
  static DateRange getLast7Days() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final start = DateTime(now.year, now.month, now.day - 6);
    return DateRange(start: start, end: end);
  }

  /// Get start and end of last 30 days
  static DateRange getLast30Days() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final start = DateTime(now.year, now.month, now.day - 29);
    return DateRange(start: start, end: end);
  }

  /// Get previous period for comparison
  static DateRange getPreviousPeriod(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final previousEnd = start.subtract(const Duration(seconds: 1));
    final previousStart = previousEnd.subtract(duration);
    return DateRange(start: previousStart, end: previousEnd);
  }

  /// Format date range as human-readable string
  static String formatDateRange(DateTime start, DateTime end, String locale) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(start.year, start.month, start.day);

    // Check if it's today
    if (startDate == today && end.day == today.day) {
      return locale == 'vi' ? 'Hôm nay' : 'Today';
    }

    // Check if it's this week
    final thisWeek = getThisWeek();
    if (start.isAfter(thisWeek.start.subtract(const Duration(seconds: 1))) &&
        end.isBefore(thisWeek.end.add(const Duration(seconds: 1)))) {
      return locale == 'vi' ? 'Tuần này' : 'This Week';
    }

    // Check if it's this month
    final thisMonth = getThisMonth();
    if (start.isAfter(thisMonth.start.subtract(const Duration(seconds: 1))) &&
        end.isBefore(thisMonth.end.add(const Duration(seconds: 1)))) {
      return locale == 'vi' ? 'Tháng này' : 'This Month';
    }

    // Check if it's this year
    final thisYear = getThisYear();
    if (start.isAfter(thisYear.start.subtract(const Duration(seconds: 1))) &&
        end.isBefore(thisYear.end.add(const Duration(seconds: 1)))) {
      return locale == 'vi' ? 'Năm này' : 'This Year';
    }

    // Otherwise return formatted date range
    final startStr = '${start.day}/${start.month}/${start.year}';
    final endStr = '${end.day}/${end.month}/${end.year}';
    return '$startStr - $endStr';
  }
}

/// Represents a date range with start and end
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});

  /// Get number of days in this range
  int get days => end.difference(start).inDays + 1;

  @override
  String toString() => 'DateRange(${start.toString()} to ${end.toString()})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DateRange && other.start == start && other.end == end;
  }

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}

/// Enum for predefined time periods
enum TimePeriod {
  today,
  thisWeek,
  thisMonth,
  thisYear,
  custom,
}

extension TimePeriodExtension on TimePeriod {
  /// Get localization key for this period
  /// Use with context.tr() to get translated label
  String get labelKey {
    switch (this) {
      case TimePeriod.today:
        return 'common.today';
      case TimePeriod.thisWeek:
        return 'common.week';
      case TimePeriod.thisMonth:
        return 'common.month';
      case TimePeriod.thisYear:
        return 'common.year';
      case TimePeriod.custom:
        return 'common.custom';
    }
  }

  DateRange getDateRange() {
    switch (this) {
      case TimePeriod.today:
        return DateRangeHelper.getToday();
      case TimePeriod.thisWeek:
        return DateRangeHelper.getThisWeek();
      case TimePeriod.thisMonth:
        return DateRangeHelper.getThisMonth();
      case TimePeriod.thisYear:
        return DateRangeHelper.getThisYear();
      case TimePeriod.custom:
        return DateRangeHelper.getThisMonth(); // Default to this month
    }
  }
}
