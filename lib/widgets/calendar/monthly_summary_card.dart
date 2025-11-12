import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_theme.dart';

/// Monthly summary card showing income, expense, and net balance
class MonthlySummaryCard extends StatelessWidget {
  final double income;
  final double expense;
  final String currency;

  const MonthlySummaryCard({
    super.key,
    required this.income,
    required this.expense,
    required this.currency,
  });

  String _formatAmount(BuildContext context, double amount) {
    if (currency == 'VND') {
      if (amount >= 1000000) {
        return '${(amount / 1000000).toStringAsFixed(1)}${context.tr('currency.suffix_million')}';
      } else if (amount >= 1000) {
        return '${(amount / 1000).toStringAsFixed(0)}${context.tr('currency.suffix_thousand')}';
      }
      return amount.toStringAsFixed(0);
    } else {
      return '${context.tr('currency.symbol_usd')}${amount.toStringAsFixed(0)}';
    }
  }

  Color _getNetBalanceColor(double netBalance) {
    if (netBalance > 0) {
      return AppTheme.success;
    } else if (netBalance < 0) {
      return AppTheme.error;
    } else {
      return AppTheme.neutral500;
    }
  }

  IconData _getNetBalanceIcon(double netBalance) {
    if (netBalance > 0) {
      return Icons.trending_up;
    } else if (netBalance < 0) {
      return Icons.trending_down;
    } else {
      return Icons.horizontal_rule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final netBalance = income - expense;
    final netBalanceColor = _getNetBalanceColor(netBalance);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryMint.withValues(alpha: 0.1),
            AppTheme.primaryGreen.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: AppTheme.borderRadiusMedium,
        border: Border.all(
          color: AppTheme.primaryMint.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('calendar.monthly_summary'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: AppTheme.spacing16),

          // Income | Expense | Net in a row
          Row(
            children: [
              // Income
              Expanded(
                child: _buildSummaryItem(
                  context,
                  label: context.tr('home.total_income'),
                  value: _formatAmount(context, income),
                  color: AppTheme.success,
                  icon: Icons.add_circle_outline,
                ),
              ),

              Container(
                width: 1,
                height: 40,
                color: colorScheme.outlineVariant,
                margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing12),
              ),

              // Expense
              Expanded(
                child: _buildSummaryItem(
                  context,
                  label: context.tr('home.total_expenses'),
                  value: _formatAmount(context, expense),
                  color: AppTheme.error,
                  icon: Icons.remove_circle_outline,
                ),
              ),

              Container(
                width: 1,
                height: 40,
                color: colorScheme.outlineVariant,
                margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing12),
              ),

              // Net Balance
              Expanded(
                child: _buildSummaryItem(
                  context,
                  label: context.tr('home.net_balance'),
                  value: _formatAmount(context, netBalance.abs()),
                  color: netBalanceColor,
                  icon: _getNetBalanceIcon(netBalance),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
