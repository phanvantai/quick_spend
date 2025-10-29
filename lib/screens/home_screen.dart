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
    // Don't initialize voice service here - only when user taps/holds button
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    debugPrint('🎤 [HomeScreen] Starting recording...');
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
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: _soundLevel),
                      duration: const Duration(milliseconds: 100),
                      builder: (context, value, child) {
                        return Container(
                          width: 100 + (value * 50),
                          height: 100 + (value * 50),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 48,
                          ),
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
    if (_isRecording) {
      return GestureDetector(
        onLongPressEnd: (_) => _stopRecording(),
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta! < -10) {
            _cancelRecording();
          }
        },
        child: Container(
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
        ),
      );
    }

    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      child: FloatingActionButton.extended(
        onPressed: () {
          _voiceService.initialize();
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
}
