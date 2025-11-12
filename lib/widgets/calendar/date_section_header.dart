import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_theme.dart';

/// Date section header for grouped expense lists
class DateSectionHeader extends StatelessWidget {
  final DateTime date;

  const DateSectionHeader({super.key, required this.date});

  String _getDateLabel(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    final locale = context.locale.languageCode;

    if (dateOnly == today) {
      return context.tr('calendar.today');
    } else if (dateOnly == yesterday) {
      return context.tr('calendar.yesterday');
    } else {
      return DateFormat.yMMMd(locale).format(date);
    }
  }

  IconData _getDateIcon() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return Icons.today;
    } else {
      return Icons.calendar_today;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: Row(
        children: [
          Icon(_getDateIcon(), size: 16, color: AppTheme.primaryMint),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            _getDateLabel(context),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Container(height: 1, color: colorScheme.outlineVariant),
          ),
        ],
      ),
    );
  }
}
