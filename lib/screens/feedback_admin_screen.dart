// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/feedback.dart';
import '../theme/app_theme.dart';

/// Admin screen to view all submitted feedback
class FeedbackAdminScreen extends StatefulWidget {
  const FeedbackAdminScreen({super.key});

  @override
  State<FeedbackAdminScreen> createState() => _FeedbackAdminScreenState();
}

class _FeedbackAdminScreenState extends State<FeedbackAdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<UserFeedback> _feedbacks = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final querySnapshot = await _firestore
          .collection('app_feedback')
          .orderBy('timestamp', descending: true)
          .get();

      final feedbacks = querySnapshot.docs
          .map((doc) => UserFeedback.fromFirestore(doc))
          .toList();

      setState(() {
        _feedbacks = feedbacks;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ [FeedbackAdminScreen] Error loading feedback: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Feedback Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFeedback,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppTheme.error,
                        ),
                        const SizedBox(height: AppTheme.spacing16),
                        Text(
                          'Error loading feedback',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        Text(
                          _error!,
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spacing24),
                        FilledButton.icon(
                          onPressed: _loadFeedback,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _feedbacks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          Text(
                            'No feedback yet',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppTheme.spacing8),
                          Text(
                            'Feedback submissions will appear here',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      itemCount: _feedbacks.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppTheme.spacing16),
                      itemBuilder: (context, index) {
                        final feedback = _feedbacks[index];
                        return _FeedbackCard(feedback: feedback);
                      },
                    ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final UserFeedback feedback;

  const _FeedbackCard({required this.feedback});

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

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type badge and timestamp
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing12,
                    vertical: AppTheme.spacing4,
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
                        size: 16,
                        color: typeColor,
                      ),
                      const SizedBox(width: AppTheme.spacing4),
                      Text(
                        context.tr('feedback.type_${feedback.type.name}'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: typeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, y • HH:mm').format(feedback.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacing12),

            // Subject
            Text(
              feedback.subject,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: AppTheme.spacing8),

            // Message
            Text(
              feedback.message,
              style: theme.textTheme.bodyMedium,
            ),

            // Attachments
            if (feedback.attachmentUrls.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacing16),
              Text(
                'Attachments (${feedback.attachmentUrls.length})',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Wrap(
                spacing: AppTheme.spacing8,
                runSpacing: AppTheme.spacing8,
                children: feedback.attachmentUrls.map((url) {
                  return GestureDetector(
                    onTap: () => _showFullImage(context, url),
                    child: ClipRRect(
                      borderRadius: AppTheme.borderRadiusSmall,
                      child: Image.network(
                        url,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 100,
                            height: 100,
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
                            width: 100,
                            height: 100,
                            color: colorScheme.surfaceContainerHighest,
                            child: const Icon(
                              Icons.broken_image,
                              color: AppTheme.error,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: AppTheme.spacing12),
            const Divider(),
            const SizedBox(height: AppTheme.spacing8),

            // Metadata
            Row(
              children: [
                Icon(
                  Icons.phone_android,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTheme.spacing4),
                Text(
                  '${feedback.platform} • v${feedback.appVersion}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  'ID: ${feedback.id.substring(0, 8)}...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
