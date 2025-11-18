import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/feedback.dart';
import '../theme/app_theme.dart';

/// Detail screen for viewing a single feedback submission
class FeedbackDetailScreen extends StatelessWidget {
  final UserFeedback feedback;

  const FeedbackDetailScreen({
    super.key,
    required this.feedback,
  });

  Color _getTypeColor(FeedbackType type) {
    switch (type) {
      case FeedbackType.bug:
        return AppTheme.error;
      case FeedbackType.feature:
        return AppTheme.info;
      case FeedbackType.general:
        return AppTheme.accentTeal;
    }
  }

  IconData _getTypeIcon(FeedbackType type) {
    switch (type) {
      case FeedbackType.bug:
        return Icons.bug_report;
      case FeedbackType.feature:
        return Icons.lightbulb_outline;
      case FeedbackType.general:
        return Icons.feedback_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final typeColor = _getTypeColor(feedback.type);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Feedback Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        children: [
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing8,
            ),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.15),
              borderRadius: AppTheme.borderRadiusSmall,
              border: Border.all(
                color: typeColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getTypeIcon(feedback.type),
                  size: 20,
                  color: typeColor,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  context.tr('feedback.type_${feedback.type.name}'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: typeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacing24),

          // Subject
          Text(
            'Subject',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            feedback.subject,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: AppTheme.spacing24),

          // Message
          Text(
            'Message',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Text(
                feedback.message,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacing24),

          // Attachments
          if (feedback.attachmentUrls.isNotEmpty) ...[
            Text(
              'Attachments (${feedback.attachmentUrls.length})',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            ...feedback.attachmentUrls.asMap().entries.map((entry) {
              final index = entry.key;
              final url = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Image ${index + 1}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    GestureDetector(
                      onTap: () => _showFullImage(context, url),
                      child: ClipRRect(
                        borderRadius: AppTheme.borderRadiusMedium,
                        child: Image.network(
                          url,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              color: colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              color: colorScheme.surfaceContainerHighest,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.broken_image,
                                    size: 48,
                                    color: AppTheme.error,
                                  ),
                                  const SizedBox(height: AppTheme.spacing8),
                                  Text(
                                    'Failed to load image',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppTheme.error,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacing4),
                                  Text(
                                    error.toString(),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: AppTheme.spacing12),
          ],

          // Metadata
          const Divider(),
          const SizedBox(height: AppTheme.spacing16),

          Text(
            'Metadata',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),

          _buildMetadataRow(
            context,
            Icons.access_time,
            'Submitted',
            DateFormat('MMMM d, y • HH:mm:ss').format(feedback.timestamp),
          ),
          _buildMetadataRow(
            context,
            Icons.phone_android,
            'Platform',
            feedback.platform.toUpperCase(),
          ),
          _buildMetadataRow(
            context,
            Icons.info_outline,
            'App Version',
            feedback.appVersion,
          ),
          _buildMetadataRow(
            context,
            Icons.fingerprint,
            'Feedback ID',
            feedback.id,
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
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
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            SizedBox.expand(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
