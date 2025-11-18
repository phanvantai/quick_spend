import 'package:cloud_firestore/cloud_firestore.dart';

/// Feedback model for storing user feedback in Firestore
class UserFeedback {
  final String id;
  final String subject;
  final String message;
  final FeedbackType type;
  final List<String> attachmentUrls;
  final DateTime timestamp;
  final String appVersion;
  final String platform;

  UserFeedback({
    required this.id,
    required this.subject,
    required this.message,
    required this.type,
    this.attachmentUrls = const [],
    required this.timestamp,
    required this.appVersion,
    required this.platform,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'subject': subject,
      'message': message,
      'type': type.name,
      'attachmentUrls': attachmentUrls,
      'timestamp': Timestamp.fromDate(timestamp),
      'appVersion': appVersion,
      'platform': platform,
    };
  }

  /// Create from Firestore document
  factory UserFeedback.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserFeedback(
      id: data['id'] as String,
      subject: data['subject'] as String,
      message: data['message'] as String,
      type: FeedbackType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => FeedbackType.general,
      ),
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      appVersion: data['appVersion'] as String,
      platform: data['platform'] as String,
    );
  }

  /// Copy with method
  UserFeedback copyWith({
    String? id,
    String? subject,
    String? message,
    FeedbackType? type,
    List<String>? attachmentUrls,
    DateTime? timestamp,
    String? appVersion,
    String? platform,
  }) {
    return UserFeedback(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      message: message ?? this.message,
      type: type ?? this.type,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      timestamp: timestamp ?? this.timestamp,
      appVersion: appVersion ?? this.appVersion,
      platform: platform ?? this.platform,
    );
  }

  @override
  String toString() {
    return 'UserFeedback(id: $id, subject: $subject, type: ${type.name}, timestamp: $timestamp)';
  }
}

/// Feedback type enum
enum FeedbackType {
  bug,
  feature,
  general,
}

/// Extension for FeedbackType
extension FeedbackTypeExtension on FeedbackType {
  String get displayName {
    switch (this) {
      case FeedbackType.bug:
        return 'Bug Report';
      case FeedbackType.feature:
        return 'Feature Request';
      case FeedbackType.general:
        return 'General Feedback';
    }
  }
}
