import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../screens/paywall_screen.dart';
import '../../theme/app_theme.dart';

/// Dialog prompting users to upgrade to premium
class UpgradePromptDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData? icon;

  const UpgradePromptDialog({
    super.key,
    required this.title,
    required this.message,
    this.icon,
  });

  /// Show the upgrade dialog
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    IconData? icon,
  }) {
    return showDialog(
      context: context,
      builder: (context) => UpgradePromptDialog(
        title: title,
        message: message,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: const EdgeInsets.all(AppTheme.spacing24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon ?? Icons.workspace_premium_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppTheme.spacing20),

          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing12),

          // Message
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    context.tr('subscription.maybe_later'),
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PaywallScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    context.tr('subscription.upgrade_prompt_button'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
