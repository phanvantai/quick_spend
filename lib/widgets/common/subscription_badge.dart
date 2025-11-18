import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_theme.dart';

/// Badge widget to show Premium status
class SubscriptionBadge extends StatelessWidget {
  final bool isPremium;
  final double? fontSize;

  const SubscriptionBadge({
    super.key,
    required this.isPremium,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPremium) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: fontSize ?? 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            context.tr('subscription.premium_badge'),
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize ?? 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
