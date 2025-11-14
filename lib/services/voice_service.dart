import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';

/// Service for handling voice input with speech-to-text
class VoiceService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Initialize the speech service
  /// Note: Speech permission on iOS is auto-requested by SpeechToText.initialize()
  Future<bool> initialize() async {
    debugPrint('🎙️ [VoiceService] Initializing...');
    if (_isInitialized) {
      debugPrint('✅ [VoiceService] Already initialized');
      return true;
    }

    try {
      // Check microphone permission (should already be granted before calling this)
      debugPrint('🔐 [VoiceService] Checking microphone permission...');
      final micStatus = await Permission.microphone.status;
      debugPrint('📋 [VoiceService] Microphone permission: ${micStatus.name}');

      if (!micStatus.isGranted) {
        debugPrint('❌ [VoiceService] Microphone permission not granted');
        return false;
      }

      // Initialize speech to text
      // On iOS, this will automatically request speech permission if needed
      debugPrint('🎤 [VoiceService] Initializing speech-to-text...');
      debugPrint('💡 [VoiceService] iOS speech permission will be auto-requested if needed');

      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          debugPrint('❌ [VoiceService] Speech recognition error: ${error.errorMsg}');
        },
        onStatus: (status) {
          debugPrint('📊 [VoiceService] Speech recognition status: $status');
        },
      );

      debugPrint('✅ [VoiceService] Initialization complete: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      debugPrint('❌ [VoiceService] Error initializing: $e');
      return false;
    }
  }

  /// Check if required permissions are granted
  /// On Android: only microphone permission needed
  /// On iOS: both microphone and speech permissions needed
  Future<bool> hasPermission() async {
    final micStatus = await Permission.microphone.status;
    debugPrint('🔐 [VoiceService.hasPermission] Microphone status: ${micStatus.name} (isGranted: ${micStatus.isGranted})');

    // On Android, only microphone permission is needed
    if (Platform.isAndroid) {
      return micStatus.isGranted;
    }

    // On iOS, both microphone and speech permissions are needed
    final speechStatus = await Permission.speech.status;
    debugPrint('🔐 [VoiceService.hasPermission] Speech status: ${speechStatus.name} (isGranted: ${speechStatus.isGranted})');

    final hasPermission = micStatus.isGranted && speechStatus.isGranted;
    debugPrint('🔐 [VoiceService.hasPermission] Result: $hasPermission');
    return hasPermission;
  }

  /// Request microphone permission
  /// Note: Speech permission on iOS is auto-requested by SpeechToText.initialize()
  Future<bool> requestPermission() async {
    debugPrint('🔐 [VoiceService.requestPermission] Requesting microphone permission...');

    final micStatus = await Permission.microphone.request();
    debugPrint('🔐 [VoiceService.requestPermission] Microphone result: ${micStatus.name}');

    return micStatus.isGranted;
  }

  /// Get detailed permission status
  Future<Map<String, PermissionStatus>> getPermissionStatus() async {
    final status = {
      'microphone': await Permission.microphone.status,
    };

    // Only add speech permission on iOS
    if (Platform.isIOS) {
      status['speech'] = await Permission.speech.status;
    }

    return status;
  }

  /// Start listening for speech
  /// [language] can be 'en' or 'vi'
  /// [onResult] callback when speech is recognized
  Future<bool> startListening({
    required String language,
    required Function(String) onResult,
    Function(double)? onSoundLevel,
  }) async {
    debugPrint('🎧 [VoiceService] Starting to listen (language: $language)');

    if (!_isInitialized) {
      debugPrint('⚠️ [VoiceService] Not initialized, initializing now...');
      final initialized = await initialize();
      if (!initialized) {
        debugPrint('❌ [VoiceService] Initialization failed');
        return false;
      }
    }

    // If already listening or speech service is still active, stop it first
    if (_isListening || _speechToText.isListening) {
      debugPrint('⚠️ [VoiceService] Already listening, stopping first...');
      await _speechToText.stop();
      _isListening = false;
      // Add small delay to ensure service is fully stopped
      await Future.delayed(const Duration(milliseconds: AppConstants.voiceStopDelayMs));
    }

    try {
      // Set listening state BEFORE starting to prevent race condition
      _isListening = true;

      // Map language code to locale ID
      final localeId = _getLocaleId(language);
      debugPrint('🌍 [VoiceService] Using locale: $localeId');

      await _speechToText.listen(
        onResult: (result) {
          debugPrint('📝 [VoiceService] Result received:');
          debugPrint('   Recognized: "${result.recognizedWords}"');
          debugPrint('   Final: ${result.finalResult}');
          debugPrint('   Confidence: ${result.confidence}');

          // Always update with latest recognized words, even if not final
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }

          if (result.finalResult) {
            debugPrint('✅ [VoiceService] Final result: "${result.recognizedWords}"');
          }
        },
        localeId: localeId,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          cancelOnError: true,
          partialResults: true,
        ),
        onSoundLevelChange: onSoundLevel,
      );

      debugPrint('✅ [VoiceService] Listen command sent');
      return true;
    } catch (e) {
      debugPrint('❌ [VoiceService] Error starting listening: $e');
      _isListening = false;
      return false;
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    debugPrint('🛑 [VoiceService] Stopping listening...');
    debugPrint('   _isListening flag: $_isListening');
    debugPrint('   SpeechToText.isListening: ${_speechToText.isListening}');

    if (!_isListening && !_speechToText.isListening) {
      debugPrint('⚠️ [VoiceService] Not currently listening');
      return;
    }

    try {
      // ALWAYS call stop() if our flag is set, even if SpeechToText.isListening
      // is still false - this handles the race condition where stop is called
      // before the async listen() operation completes
      if (_isListening || _speechToText.isListening) {
        await _speechToText.stop();
      }
      _isListening = false;
      debugPrint('✅ [VoiceService] Stopped listening');
    } catch (e) {
      debugPrint('❌ [VoiceService] Error stopping listening: $e');
      _isListening = false;
    }
  }

  /// Cancel listening
  Future<void> cancelListening() async {
    debugPrint('❌ [VoiceService] Canceling listening...');
    debugPrint('   _isListening flag: $_isListening');
    debugPrint('   SpeechToText.isListening: ${_speechToText.isListening}');

    if (!_isListening && !_speechToText.isListening) {
      debugPrint('⚠️ [VoiceService] Not currently listening');
      return;
    }

    try {
      // ALWAYS call cancel() if our flag is set (same race condition handling)
      if (_isListening || _speechToText.isListening) {
        await _speechToText.cancel();
      }
      _isListening = false;
      debugPrint('✅ [VoiceService] Canceled listening');
    } catch (e) {
      debugPrint('❌ [VoiceService] Error canceling listening: $e');
      _isListening = false;
    }
  }

  /// Get available locales
  Future<List<String>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }

    final locales = await _speechToText.locales();
    return locales.map((locale) => locale.localeId).toList();
  }

  /// Check if a specific locale is available
  Future<bool> isLocaleAvailable(String language) async {
    final locales = await getAvailableLocales();
    final localeId = _getLocaleId(language);
    return locales.any((locale) => locale.startsWith(localeId.split('_')[0]));
  }

  /// Map language code to speech recognition locale ID
  String _getLocaleId(String language) {
    switch (language) {
      case 'vi':
        return 'vi_VN'; // Vietnamese
      case 'ja':
        return 'ja_JP'; // Japanese
      case 'ko':
        return 'ko_KR'; // Korean
      case 'th':
        return 'th_TH'; // Thai
      case 'es':
        return 'es_ES'; // Spanish (Spain)
      case 'en':
      default:
        return 'en_US'; // English (US)
    }
  }

  /// Dispose resources
  void dispose() {
    if (_isListening) {
      _speechToText.stop();
    }
    _isListening = false;
    _isInitialized = false;
  }
}
