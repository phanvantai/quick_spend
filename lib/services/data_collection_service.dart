import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as developer;

/// Service for collecting training data to improve expense classification
///
/// Privacy-First Approach:
/// - All data is anonymized with UUID user IDs
/// - User must opt-in before any data is collected
/// - Only collects: input text, amounts, categories (NO personal data)
/// - Data stored in Firestore for centralized model training
class DataCollectionService {
  static const String _userIdKey = 'anonymous_user_id';
  static const String _dataCollectionConsentKey = 'data_collection_consent';

  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  String? _anonymousUserId;
  bool? _hasConsent;
  String? _appVersion;

  DataCollectionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Initialize the service and load user ID
  Future<void> init() async {
    await _loadOrCreateUserId();
    await _loadConsent();
    await _loadAppVersion();
  }

  /// Load or create anonymous user ID
  Future<void> _loadOrCreateUserId() async {
    final prefs = await SharedPreferences.getInstance();

    _anonymousUserId = prefs.getString(_userIdKey);

    if (_anonymousUserId == null) {
      // Generate new anonymous ID
      _anonymousUserId = _uuid.v4();
      await prefs.setString(_userIdKey, _anonymousUserId!);
      developer.log('📊 Generated new anonymous user ID: $_anonymousUserId');
    } else {
      developer.log('📊 Loaded existing anonymous user ID: $_anonymousUserId');
    }
  }

  /// Load user consent status
  Future<void> _loadConsent() async {
    final prefs = await SharedPreferences.getInstance();
    _hasConsent = prefs.getBool(_dataCollectionConsentKey);
    developer.log('📊 Data collection consent: ${_hasConsent ?? "not set"}');
  }

  /// Load app version
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
    } catch (e) {
      _appVersion = 'unknown';
      developer.log('⚠️ Failed to load app version: $e');
    }
  }

  /// Set user consent for data collection
  Future<void> setConsent(bool consent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dataCollectionConsentKey, consent);
    _hasConsent = consent;
    developer.log('📊 Data collection consent updated: $consent');
  }

  /// Check if user has given consent
  Future<bool> hasConsent() async {
    if (_hasConsent == null) {
      await _loadConsent();
    }
    return _hasConsent ?? false;
  }

  /// Check if user has been asked for consent
  Future<bool> hasBeenAskedForConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_dataCollectionConsentKey);
  }

  /// Get anonymous user ID
  String? get anonymousUserId => _anonymousUserId;

  /// Log expense parsing data for training
  ///
  /// This captures the raw input, parsed result, and user's final decision
  Future<void> logExpenseParsing({
    required String rawInput,
    required String description,
    required double amount,
    required String predictedCategory,
    required String finalCategory,
    required double confidence,
    required String language,
    required String inputMethod, // 'voice' or 'manual'
    required String parserUsed, // 'gemini' or 'fallback'
  }) async {
    // Check consent first
    if (!await hasConsent()) {
      developer.log('📊 Skipping data collection - no user consent');
      return;
    }

    if (_anonymousUserId == null) {
      await _loadOrCreateUserId();
    }

    try {
      final data = {
        'rawInput': rawInput,
        'description': description,
        'amount': amount,
        'predictedCategory': predictedCategory,
        'finalCategory': finalCategory,
        'wasCorrected': predictedCategory != finalCategory,
        'confidence': confidence,
        'language': language,
        'inputMethod': inputMethod,
        'parserUsed': parserUsed,
        'userId': _anonymousUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'appVersion': _appVersion ?? 'unknown',
      };

      await _firestore.collection('training_data').add(data);

      developer.log('📊 Logged training data: $description ($predictedCategory → $finalCategory)');
    } catch (e) {
      developer.log('⚠️ Failed to log training data: $e');
      // Fail silently - don't disrupt user experience
    }
  }

  /// Log category correction event (when user manually changes category)
  ///
  /// This is GOLD DATA - shows where the model made mistakes
  Future<void> logCategoryCorrection({
    required String expenseId,
    required String rawInput,
    required String description,
    required double amount,
    required String originalCategory,
    required String correctedCategory,
    required String language,
  }) async {
    // Check consent first
    if (!await hasConsent()) {
      developer.log('📊 Skipping correction logging - no user consent');
      return;
    }

    if (_anonymousUserId == null) {
      await _loadOrCreateUserId();
    }

    try {
      final data = {
        'expenseId': expenseId,
        'rawInput': rawInput,
        'description': description,
        'amount': amount,
        'originalCategory': originalCategory,
        'correctedCategory': correctedCategory,
        'language': language,
        'userId': _anonymousUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'appVersion': _appVersion ?? 'unknown',
      };

      await _firestore.collection('user_corrections').add(data);

      developer.log('📊 Logged category correction: $description ($originalCategory → $correctedCategory)');
    } catch (e) {
      developer.log('⚠️ Failed to log category correction: $e');
      // Fail silently - don't disrupt user experience
    }
  }

  /// Get statistics about collected data (for debugging/testing)
  Future<Map<String, dynamic>> getCollectionStats() async {
    if (_anonymousUserId == null) {
      await _loadOrCreateUserId();
    }

    try {
      final trainingDataQuery = await _firestore
          .collection('training_data')
          .where('userId', isEqualTo: _anonymousUserId)
          .get();

      final correctionsQuery = await _firestore
          .collection('user_corrections')
          .where('userId', isEqualTo: _anonymousUserId)
          .get();

      return {
        'trainingDataCount': trainingDataQuery.docs.length,
        'correctionsCount': correctionsQuery.docs.length,
        'userId': _anonymousUserId,
        'hasConsent': await hasConsent(),
      };
    } catch (e) {
      developer.log('⚠️ Failed to get collection stats: $e');
      return {
        'error': e.toString(),
      };
    }
  }
}
