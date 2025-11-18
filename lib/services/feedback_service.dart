import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/feedback.dart';

/// Service for submitting user feedback to Firestore with image attachments
class FeedbackService {
  static const String _collectionName = 'app_feedback';
  static const String _storagePath = 'feedback_attachments';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  /// Submit feedback with optional image attachments
  ///
  /// Returns true if successful, false otherwise
  /// Throws exception on error
  Future<bool> submitFeedback({
    required String subject,
    required String message,
    required FeedbackType type,
    required String appVersion,
    required String platform,
    List<File>? attachments,
  }) async {
    try {
      debugPrint('📝 [FeedbackService] Submitting feedback...');

      // Generate unique feedback ID
      final feedbackId = _uuid.v4();

      // Upload attachments if any
      List<String> attachmentUrls = [];
      if (attachments != null && attachments.isNotEmpty) {
        debugPrint(
          '📎 [FeedbackService] Uploading ${attachments.length} attachments...',
        );
        attachmentUrls = await _uploadAttachments(feedbackId, attachments);
        debugPrint(
          '✅ [FeedbackService] Uploaded ${attachmentUrls.length} attachments',
        );
      }

      // Create feedback object
      final feedback = UserFeedback(
        id: feedbackId,
        subject: subject,
        message: message,
        type: type,
        attachmentUrls: attachmentUrls,
        timestamp: DateTime.now(),
        appVersion: appVersion,
        platform: platform,
      );

      // Save to Firestore
      await _firestore
          .collection(_collectionName)
          .doc(feedbackId)
          .set(feedback.toFirestore());

      debugPrint('✅ [FeedbackService] Feedback submitted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ [FeedbackService] Error submitting feedback: $e');
      rethrow;
    }
  }

  /// Upload image attachments to Firebase Storage
  ///
  /// Returns list of download URLs
  Future<List<String>> _uploadAttachments(
    String feedbackId,
    List<File> files,
  ) async {
    final List<String> urls = [];

    for (int i = 0; i < files.length; i++) {
      try {
        final file = files[i];
        final fileName = 'image_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final path = '$_storagePath/$feedbackId/$fileName';

        debugPrint('📤 [FeedbackService] Uploading $fileName to $path...');

        // Upload file
        final ref = _storage.ref().child(path);
        debugPrint('🔄 [FeedbackService] Starting upload...');
        final uploadTask = await ref.putFile(file);
        debugPrint('✅ [FeedbackService] Upload complete, getting download URL...');

        // Get download URL
        try {
          final downloadUrl = await uploadTask.ref.getDownloadURL();
          urls.add(downloadUrl);
          debugPrint('✅ [FeedbackService] Got download URL: ${downloadUrl.substring(0, 50)}...');
        } catch (urlError) {
          debugPrint('❌ [FeedbackService] Failed to get download URL: $urlError');
          debugPrint('⚠️ [FeedbackService] Image uploaded but URL not retrieved - check Storage rules!');
          // Rethrow to indicate failure
          rethrow;
        }

        debugPrint('✅ [FeedbackService] Successfully processed: $fileName');
      } catch (e) {
        debugPrint('❌ [FeedbackService] Error uploading attachment $i: $e');
        debugPrint('📍 [FeedbackService] Error details: ${e.runtimeType}');
        // Continue with other uploads even if one fails
      }
    }

    debugPrint('📊 [FeedbackService] Upload summary: ${urls.length}/${files.length} attachments successful');
    return urls;
  }

  /// Check if Firestore is available/configured
  ///
  /// Returns true if Firestore is accessible
  Future<bool> isAvailable() async {
    try {
      await _firestore
          .collection(_collectionName)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      debugPrint('⚠️ [FeedbackService] Firestore not available: $e');
      return false;
    }
  }

  /// Delete feedback attachments from Storage (for cleanup)
  ///
  /// This is a utility method for manual cleanup if needed
  Future<void> deleteAttachments(String feedbackId) async {
    try {
      final ref = _storage.ref().child('$_storagePath/$feedbackId');
      final listResult = await ref.listAll();

      for (final item in listResult.items) {
        await item.delete();
        debugPrint('🗑️ [FeedbackService] Deleted: ${item.name}');
      }

      debugPrint('✅ [FeedbackService] All attachments deleted for $feedbackId');
    } catch (e) {
      debugPrint('❌ [FeedbackService] Error deleting attachments: $e');
    }
  }
}
