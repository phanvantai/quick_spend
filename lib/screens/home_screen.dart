import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/app_config_provider.dart';
import '../services/voice_service.dart';
import '../services/expense_parser.dart';

/// Home screen - main app interface
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VoiceService _voiceService = VoiceService();
  bool _isRecording = false;
  double _soundLevel = 0.0;
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    // Don't initialize voice service here to avoid immediate permission request
    // It will be initialized on first use
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    debugPrint('🎤 [HomeScreen] Starting recording...');

    // Check if we have microphone permission
    final hasPermission = await _voiceService.hasPermission();
    debugPrint('🔐 [HomeScreen] Has microphone permission: $hasPermission');

    if (!hasPermission) {
      // Show rationale dialog before requesting permission
      final shouldRequest = await _showPermissionRationale();
      if (!shouldRequest || !mounted) {
        debugPrint('❌ [HomeScreen] User declined permission rationale');
        return;
      }

      // Request permission
      final granted = await _voiceService.requestPermission();
      debugPrint('🔐 [HomeScreen] Permission granted: $granted');

      if (!granted) {
        debugPrint('❌ [HomeScreen] Microphone permission denied');
        if (mounted) {
          _showPermissionDeniedDialog();
        }
        return;
      }
    }

    if (!mounted) return;
    final configProvider = context.read<AppConfigProvider>();
    final language = configProvider.language;
    debugPrint('🌍 [HomeScreen] Language: $language');

    setState(() {
      _isRecording = true;
      _recognizedText = '';
    });

    final success = await _voiceService.startListening(
      language: language,
      onResult: (text) {
        debugPrint('📝 [HomeScreen] Recognized text: "$text"');
        setState(() {
          _recognizedText = text;
        });
      },
      onSoundLevel: (level) {
        debugPrint('🔊 [HomeScreen] Sound level: $level');
        setState(() {
          _soundLevel = level;
        });
      },
    );

    debugPrint('✅ [HomeScreen] Start listening success: $success');

    if (!success) {
      debugPrint('❌ [HomeScreen] Failed to start listening');
      setState(() {
        _isRecording = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('voice.error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    debugPrint('🛑 [HomeScreen] Stopping recording...');
    await _voiceService.stopListening();
    setState(() {
      _isRecording = false;
    });

    debugPrint('📄 [HomeScreen] Final recognized text: "$_recognizedText"');

    // Parse the recognized text
    if (_recognizedText.isNotEmpty) {
      _processExpense(_recognizedText);
    } else {
      debugPrint('⚠️ [HomeScreen] No text recognized');
    }
  }

  Future<void> _cancelRecording() async {
    debugPrint('❌ [HomeScreen] Canceling recording...');
    await _voiceService.cancelListening();
    setState(() {
      _isRecording = false;
      _recognizedText = '';
    });
  }

  void _processExpense(String input) {
    debugPrint('💰 [HomeScreen] Processing expense: "$input"');
    final result = ExpenseParser.parse(input, 'user123'); // TODO: Real user ID

    debugPrint('📊 [HomeScreen] Parse result: ${result.toString()}');

    if (result.success && result.expense != null) {
      final expense = result.expense!;
      debugPrint('✅ [HomeScreen] Expense parsed successfully:');
      debugPrint('   Amount: ${expense.amount}');
      debugPrint('   Description: ${expense.description}');
      debugPrint('   Category: ${expense.category}');
      debugPrint('   Language: ${expense.language}');
      debugPrint('   Confidence: ${result.overallConfidence}');

      // Show success with expense details
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Expense Recorded!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount: ${result.expense!.getFormattedAmount()}'),
              Text('Description: ${result.expense!.description}'),
              Text(
                'Category: ${result.expense!.category.toString().split('.').last}',
              ),
              if (result.overallConfidence != null &&
                  result.overallConfidence! < 0.7)
                const Text(
                  '\nLow confidence - please verify',
                  style: TextStyle(color: Colors.orange),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      debugPrint(
        '❌ [HomeScreen] Failed to parse expense: ${result.errorMessage}',
      );
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Failed to parse expense'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = context.watch<AppConfigProvider>();
    final currency = configProvider.currency;

    return Scaffold(
      appBar: AppBar(
        title: Text('home.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('settings.coming_soon'.tr())),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wallet_outlined,
                    size: 80,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'home.welcome'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.language,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'home.language_label'.tr(),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.attach_money,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'home.currency_label'.tr(
                                namedArgs: {'currency': currency},
                              ),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    '${'home.coming_soon'.tr()}\n\n${'home.features'.tr()}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Recording overlay
          if (_isRecording)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated microphone with ripple effect
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: _soundLevel),
                      duration: const Duration(milliseconds: 100),
                      builder: (context, value, child) {
                        // Sound level comes as negative dB (e.g., -40.0 to -20.0)
                        // Convert to 0.0-1.0 range for animation
                        // Typical range: -60 dB (quiet) to -20 dB (loud)
                        final normalizedLevel = ((value + 60) / 40).clamp(0.0, 1.0);

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer ripple
                            _buildRipple(
                              delay: 0,
                              minSize: 120,
                              maxSize: 180,
                              opacity: 0.3,
                            ),
                            // Middle ripple
                            _buildRipple(
                              delay: 400,
                              minSize: 110,
                              maxSize: 160,
                              opacity: 0.4,
                            ),
                            // Inner circle with sound level animation
                            Container(
                              width: 100.0 + (normalizedLevel * 30.0),
                              height: 100.0 + (normalizedLevel * 30.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.5),
                                    blurRadius: 20 + (normalizedLevel * 10),
                                    spreadRadius: 5 + (normalizedLevel * 5),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.mic,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'voice.listening'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_recognizedText.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _recognizedText,
                          style: const TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    Text(
                      'voice.slide_to_cancel'.tr(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildVoiceButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildVoiceButton() {
    return GestureDetector(
      onLongPressStart: (_isRecording)
          ? null
          : (_) {
              debugPrint('👆 [HomeScreen] Long press started');
              _startRecording();
            },
      onLongPressEnd: (_isRecording)
          ? (_) {
              debugPrint('👆 [HomeScreen] Long press ended');
              _stopRecording();
            }
          : null,
      onVerticalDragUpdate: (_isRecording)
          ? (details) {
              if (details.primaryDelta! < -10) {
                debugPrint('👆 [HomeScreen] Slide to cancel detected');
                _cancelRecording();
              }
            }
          : null,
      child: _isRecording
          ? Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 36),
            )
          : FloatingActionButton.extended(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('voice.hold_instruction'.tr()),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.mic),
              label: Text('voice.hold_to_record'.tr()),
              heroTag: 'voice_button',
            ),
    );
  }

  Widget _buildRipple({
    required int delay,
    required double minSize,
    required double maxSize,
    required double opacity,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOut,
      onEnd: () {
        // Trigger rebuild to restart animation
        if (mounted && _isRecording) {
          setState(() {});
        }
      },
      builder: (context, value, child) {
        return Container(
          width: minSize + ((maxSize - minSize) * value),
          height: minSize + ((maxSize - minSize) * value),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.red.withValues(
                alpha: opacity * (1.0 - value),
              ),
              width: 2,
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showPermissionRationale() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.mic, color: Colors.blue),
            const SizedBox(width: 12),
            Text('voice.permission_title'.tr()),
          ],
        ),
        content: Text('voice.permission_rationale'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('common.allow'.tr()),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 12),
            Text('voice.permission_denied_title'.tr()),
          ],
        ),
        content: Text('voice.permission_denied_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.ok'.tr()),
          ),
        ],
      ),
    );
  }
}
