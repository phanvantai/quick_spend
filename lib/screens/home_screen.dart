import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/app_config_provider.dart';
import '../services/voice_service.dart';
import '../services/expense_parser.dart';
import '../theme/app_theme.dart';
import '../widgets/common/empty_state.dart';

/// Home Screen with modern UI and voice input
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
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    debugPrint('🎤 [HomeScreen] Starting recording...');

    final hasPermission = await _voiceService.hasPermission();
    debugPrint('🔐 [HomeScreen] Has microphone permission: $hasPermission');

    if (!hasPermission) {
      final shouldRequest = await _showPermissionRationale();
      if (!shouldRequest || !mounted) {
        debugPrint('❌ [HomeScreen] User declined permission rationale');
        return;
      }

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

    setState(() {
      _isRecording = true;
      _recognizedText = '';
    });

    final success = await _voiceService.startListening(
      language: language,
      onResult: (text) {
        setState(() {
          _recognizedText = text;
        });
      },
      onSoundLevel: (level) {
        setState(() {
          _soundLevel = level;
        });
      },
    );

    if (!success && mounted) {
      setState(() {
        _isRecording = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('voice.error'.tr()),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    debugPrint('🛑 [HomeScreen] Stopping recording...');
    await _voiceService.stopListening();
    setState(() {
      _isRecording = false;
    });

    if (_recognizedText.isNotEmpty) {
      _processExpense(_recognizedText);
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

  Future<void> _processExpense(String input) async {
    debugPrint('💰 [HomeScreen] Processing expense: "$input"');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppTheme.spacing16),
                Text(
                  'Parsing expense...',
                  style: AppTheme.lightTextTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final results = await ExpenseParser.parse(input, 'user123');
      if (mounted) Navigator.pop(context);

      if (results.isEmpty || !results.any((r) => r.success)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to parse expense'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
        return;
      }

      final successfulResults = results
          .where((r) => r.success && r.expense != null)
          .toList();
      if (mounted && successfulResults.isNotEmpty) {
        _showExpenseResultsDialog(successfulResults);
      }
    } catch (e) {
      debugPrint('❌ [HomeScreen] Error: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showExpenseResultsDialog(List<ParseResult> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          results.length > 1
              ? '${results.length} Expenses Recorded!'
              : 'Expense Recorded!',
          style: AppTheme.lightTextTheme.headlineSmall,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < results.length; i++) ...[
                if (results.length > 1) ...[
                  Text(
                    'Expense ${i + 1}',
                    style: AppTheme.lightTextTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                ],
                _buildExpenseDetails(results[i]),
                if (i < results.length - 1) ...[
                  const Divider(height: AppTheme.spacing24),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseDetails(ParseResult result) {
    final expense = result.expense!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Amount: ${expense.getFormattedAmount()}'),
        Text('Description: ${expense.description}'),
        Text('Category: ${expense.category.toString().split('.').last}'),
        if (result.overallConfidence != null && result.overallConfidence! < 0.7)
          Text(
            '\nLow confidence - please verify',
            style: AppTheme.lightTextTheme.bodySmall?.copyWith(
              color: AppTheme.warning,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutral50,
      body: Stack(
        children: [
          // Main content
          CustomScrollView(
            slivers: [
              // App bar with gradient
              SliverAppBar(
                expandedHeight: 160,
                floating: false,
                pinned: true,
                backgroundColor: AppTheme.primaryPurple,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacing24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            const SizedBox(height: AppTheme.spacing12),
                            Text(
                              'home.welcome'.tr(),
                              style: AppTheme.lightTextTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: AppTheme.spacing16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('settings.coming_soon'.tr())),
                      );
                    },
                  ),
                ],
              ),

              // Content
              SliverPadding(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Empty state
                    EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No expenses yet',
                      message:
                          'Start tracking your spending by adding your first expense using voice or text input.',
                      actionLabel: 'Add Expense',
                      onAction: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('voice.hold_instruction'.tr()),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ]),
                ),
              ),
            ],
          ),

          // Recording overlay
          if (_isRecording)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.9),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated microphone
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: _soundLevel),
                      duration: const Duration(milliseconds: 100),
                      builder: (context, value, child) {
                        final normalizedLevel = ((value + 60) / 40).clamp(
                          0.0,
                          1.0,
                        );
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            _buildRipple(normalizedLevel, 180, 0.2),
                            _buildRipple(normalizedLevel, 150, 0.3),
                            Container(
                              width: 100.0 + (normalizedLevel * 30.0),
                              height: 100.0 + (normalizedLevel * 30.0),
                              decoration: BoxDecoration(
                                gradient: AppTheme.accentGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accentPink.withValues(
                                      alpha: 0.5,
                                    ),
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
                    const SizedBox(height: AppTheme.spacing24),
                    Text(
                      'voice.listening'.tr(),
                      style: AppTheme.lightTextTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_recognizedText.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spacing16),
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing32,
                        ),
                        padding: const EdgeInsets.all(AppTheme.spacing16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppTheme.borderRadiusMedium,
                          boxShadow: AppTheme.shadowLarge,
                        ),
                        child: Text(
                          _recognizedText,
                          style: AppTheme.lightTextTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTheme.spacing32),
                    Text(
                      'voice.slide_to_cancel'.tr(),
                      style: AppTheme.lightTextTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),

      // Voice FAB
      floatingActionButton: _buildVoiceFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildVoiceFAB() {
    return GestureDetector(
      onLongPressStart: _isRecording ? null : (_) => _startRecording(),
      onLongPressEnd: _isRecording ? (_) => _stopRecording() : null,
      onVerticalDragUpdate: _isRecording
          ? (details) {
              if (details.primaryDelta! < -10) {
                _cancelRecording();
              }
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          gradient: _isRecording
              ? AppTheme.accentGradient
              : AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: AppTheme.shadowLarge,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isRecording
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('voice.hold_instruction'.tr()),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing24,
                vertical: AppTheme.spacing16,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isRecording ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    _isRecording ? 'Recording...' : 'voice.hold_to_record'.tr(),
                    style: AppTheme.lightTextTheme.labelLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRipple(double level, double size, double opacity) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOut,
      onEnd: () {
        if (mounted && _isRecording) {
          setState(() {});
        }
      },
      builder: (context, value, child) {
        return Container(
          width: size * (0.7 + (0.3 * value)),
          height: size * (0.7 + (0.3 * value)),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.accentPink.withValues(
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
            const Icon(Icons.mic, color: AppTheme.info),
            const SizedBox(width: AppTheme.spacing12),
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
            const Icon(Icons.warning, color: AppTheme.warning),
            const SizedBox(width: AppTheme.spacing12),
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
