// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/feedback.dart';
import '../services/feedback_service.dart';
import '../theme/app_theme.dart';

/// Screen for submitting user feedback
class FeedbackFormScreen extends StatefulWidget {
  const FeedbackFormScreen({super.key});

  @override
  State<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends State<FeedbackFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _feedbackService = FeedbackService();
  final _imagePicker = ImagePicker();

  FeedbackType _selectedType = FeedbackType.general;
  List<File> _attachments = [];
  bool _isSubmitting = false;
  String _appVersion = '';

  static const int _maxAttachments = 3;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      });
    } catch (e) {
      setState(() {
        _appVersion = '1.0.0';
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (_attachments.length >= _maxAttachments) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'feedback.max_images',
                namedArgs: {'max': _maxAttachments.toString()},
              ),
            ),
            backgroundColor: AppTheme.warning,
          ),
        );
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _attachments.add(File(image.path));
        });
      }
    } catch (e) {
      debugPrint('❌ [FeedbackFormScreen] Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('feedback.image_pick_error')),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryMint),
              title: Text(context.tr('feedback.from_gallery')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.accentOrange),
              title: Text(context.tr('feedback.from_camera')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final platform = Platform.isAndroid ? 'android' : 'ios';

      await _feedbackService.submitFeedback(
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        type: _selectedType,
        appVersion: _appVersion,
        platform: platform,
        attachments: _attachments.isNotEmpty ? _attachments : null,
      );

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.success, size: 28),
                const SizedBox(width: 12),
                Text(context.tr('feedback.success_title')),
              ],
            ),
            content: Text(context.tr('feedback.success_message')),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close feedback form
                },
                child: Text(context.tr('common.ok')),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [FeedbackFormScreen] Error submitting feedback: $e');

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.error, color: AppTheme.error, size: 28),
                const SizedBox(width: 12),
                Text(context.tr('feedback.error_title')),
              ],
            ),
            content: Text(
              context.tr(
                'feedback.error_message',
                namedArgs: {'error': e.toString()},
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('common.ok')),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(context.tr('feedback.title')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          children: [
            // Subject field
            TextFormField(
              controller: _subjectController,
              decoration: InputDecoration(
                labelText: context.tr('feedback.subject'),
                hintText: context.tr('feedback.subject_hint'),
                prefixIcon: const Icon(Icons.title),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('feedback.subject_required');
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: AppTheme.spacing16),

            // Feedback type dropdown
            DropdownButtonFormField<FeedbackType>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: context.tr('feedback.type'),
                prefixIcon: const Icon(Icons.category),
                border: const OutlineInputBorder(),
              ),
              items: FeedbackType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(context.tr('feedback.type_${type.name}')),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value ?? FeedbackType.general;
                });
              },
            ),

            const SizedBox(height: AppTheme.spacing16),

            // Message field
            TextFormField(
              controller: _messageController,
              decoration: InputDecoration(
                labelText: context.tr('feedback.message'),
                hintText: context.tr('feedback.message_hint'),
                prefixIcon: const Icon(Icons.message),
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('feedback.message_required');
                }
                return null;
              },
            ),

            const SizedBox(height: AppTheme.spacing24),

            // Attachments section
            Text(
              context.tr('feedback.attachments'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: AppTheme.spacing12),

            // Attachment thumbnails
            if (_attachments.isNotEmpty)
              Wrap(
                spacing: AppTheme.spacing8,
                runSpacing: AppTheme.spacing8,
                children: _attachments.asMap().entries.map((entry) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: AppTheme.borderRadiusSmall,
                        child: Image.file(
                          entry.value,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeAttachment(entry.key),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.error,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),

            const SizedBox(height: AppTheme.spacing12),

            // Add image button
            if (_attachments.length < _maxAttachments)
              OutlinedButton.icon(
                onPressed: _showImageSourceDialog,
                icon: const Icon(Icons.add_photo_alternate),
                label: Text(context.tr('feedback.add_image')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                    vertical: AppTheme.spacing12,
                  ),
                ),
              ),

            if (_attachments.length >= _maxAttachments)
              Text(
                context.tr(
                  'feedback.max_images_reached',
                  namedArgs: {'max': _maxAttachments.toString()},
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),

            const SizedBox(height: AppTheme.spacing32),

            // Submit button
            FilledButton(
              onPressed: _isSubmitting ? null : _submitFeedback,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacing16,
                ),
              ),
              child: _isSubmitting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        Text(context.tr('feedback.submitting')),
                      ],
                    )
                  : Text(context.tr('feedback.submit')),
            ),
          ],
        ),
      ),
    );
  }
}
