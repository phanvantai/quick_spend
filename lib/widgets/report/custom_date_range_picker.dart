import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_range_helper.dart';

/// Dialog for selecting custom date range
class CustomDateRangePicker extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const CustomDateRangePicker({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<CustomDateRangePicker> createState() => _CustomDateRangePickerState();

  /// Show date range picker dialog
  static Future<DateRange?> show(
    BuildContext context, {
    DateTime? initialStartDate,
    DateTime? initialEndDate,
  }) {
    return showDialog<DateRange>(
      context: context,
      builder: (context) => CustomDateRangePicker(
        initialStartDate: initialStartDate,
        initialEndDate: initialEndDate,
      ),
    );
  }
}

class _CustomDateRangePickerState extends State<CustomDateRangePicker> {
  late DateTime startDate;
  late DateTime endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startDate = widget.initialStartDate ?? DateTime(now.year, now.month, 1);
    endDate = widget.initialEndDate ?? now;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: AppTheme.borderRadiusSmall,
            ),
            child: const Icon(Icons.date_range, color: Colors.white, size: 20),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Flexible(child: Text('report.custom_date_range'.tr())),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Start date
          _buildDateSelector(
            context,
            label: 'report.start_date'.tr(),
            date: startDate,
            icon: Icons.event_outlined,
            onTap: () => _selectStartDate(context),
          ),
          const SizedBox(height: AppTheme.spacing16),

          // End date
          _buildDateSelector(
            context,
            label: 'report.end_date'.tr(),
            date: endDate,
            icon: Icons.event_outlined,
            onTap: () => _selectEndDate(context),
          ),
          const SizedBox(height: AppTheme.spacing16),

          // Quick selection chips
          Wrap(
            spacing: AppTheme.spacing8,
            runSpacing: AppTheme.spacing8,
            children: [
              _buildQuickChip(
                context,
                'report.last_7_days'.tr(),
                () => _setQuickRange(DateRangeHelper.getLast7Days()),
              ),
              _buildQuickChip(
                context,
                'report.last_30_days'.tr(),
                () => _setQuickRange(DateRangeHelper.getLast30Days()),
              ),
              _buildQuickChip(
                context,
                'report.this_month'.tr(),
                () => _setQuickRange(DateRangeHelper.getThisMonth()),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),

          // Validation message
          if (endDate.isBefore(startDate))
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: AppTheme.borderRadiusSmall,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppTheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: Text(
                      'report.end_date_before_start'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: endDate.isBefore(startDate)
              ? null
              : () {
                  Navigator.pop(
                    context,
                    DateRange(start: startDate, end: endDate),
                  );
                },
          child: Text('common.apply'.tr()),
        ),
      ],
    );
  }

  Widget _buildDateSelector(
    BuildContext context, {
    required String label,
    required DateTime date,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadiusMedium,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing8),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
          borderRadius: AppTheme.borderRadiusMedium,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryMint, size: 20),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Text(
                    DateFormat.yMMMd().format(date),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(
    BuildContext context,
    String label,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadiusSmall,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing12,
          vertical: AppTheme.spacing8,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: AppTheme.borderRadiusSmall,
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.primaryMint),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.primaryMint),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
    }
  }

  void _setQuickRange(DateRange range) {
    setState(() {
      startDate = range.start;
      endDate = range.end;
    });
  }
}
