import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../utils/date_range_helper.dart';
import '../../theme/app_theme.dart';

/// Period filter widget with tabs for Today/Week/Month/Year/Custom
class PeriodFilter extends StatelessWidget {
  final TimePeriod selectedPeriod;
  final Function(TimePeriod) onPeriodChanged;
  final VoidCallback? onCustomTap;

  const PeriodFilter({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    this.onCustomTap,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip(
            context,
            TimePeriod.today,
            TimePeriod.today.getLabel(locale),
            Icons.today,
          ),
          const SizedBox(width: AppTheme.spacing8),
          _buildFilterChip(
            context,
            TimePeriod.thisWeek,
            TimePeriod.thisWeek.getLabel(locale),
            Icons.date_range,
          ),
          const SizedBox(width: AppTheme.spacing8),
          _buildFilterChip(
            context,
            TimePeriod.thisMonth,
            TimePeriod.thisMonth.getLabel(locale),
            Icons.calendar_month,
          ),
          const SizedBox(width: AppTheme.spacing8),
          _buildFilterChip(
            context,
            TimePeriod.thisYear,
            TimePeriod.thisYear.getLabel(locale),
            Icons.calendar_today,
          ),
          const SizedBox(width: AppTheme.spacing8),
          _buildFilterChip(
            context,
            TimePeriod.custom,
            TimePeriod.custom.getLabel(locale),
            Icons.tune,
            onTap: onCustomTap,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    TimePeriod period,
    String label,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    final isSelected = selectedPeriod == period;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => onPeriodChanged(period),
        borderRadius: AppTheme.borderRadiusMedium,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing12),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.primaryGradient : null,
            color: isSelected ? null : colorScheme.surfaceContainerHighest,
            borderRadius: AppTheme.borderRadiusMedium,
            border: isSelected
                ? null
                : Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                    width: 1,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? Colors.white
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
