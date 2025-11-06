import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/app_config_provider.dart';
import '../providers/expense_provider.dart';
import '../services/voice_service.dart';
import '../services/expense_parser.dart';
import '../models/expense.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';

/// Main screen with bottom navigation bar and global voice input
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  // Voice service and state
  final VoiceService _voiceService = VoiceService();
  bool _isRecording = false;
  double _soundLevel = 0.0;
  String _recognizedText = '';
  PermissionStatus? _micPermissionStatus;
  bool _voiceServiceInitFailed = false;
  late AnimationController _listeningTextController;
  late AnimationController _swipeTextController;
  late Animation<double> _listeningFadeAnimation;
  late Animation<double> _swipeSlideAnimation;
  late WidgetsBindingObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();

    _screens = [
      const HomeScreen(),
      const ReportScreen(),
      const SettingsScreen(),
    ];

    // Check permission status on init
    _checkPermissionStatus();

    // Listen for app lifecycle changes to refresh permission status
    _lifecycleObserver = _AppLifecycleObserver(
      onResume: () {
        debugPrint('📱 [MainScreen] App resumed, rechecking permissions...');
        _checkPermissionStatus();
      },
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);

    // Listening text fade animation
    _listeningTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _listeningFadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _listeningTextController,
        curve: Curves.easeInOut,
      ),
    );

    // Swipe text slide animation
    _swipeTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _swipeSlideAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(
        parent: _swipeTextController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _listeningTextController.dispose();
    _swipeTextController.dispose();
    _voiceService.dispose();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  Future<void> _checkPermissionStatus() async {
    debugPrint('🔐 [MainScreen] Checking permission status...');
    debugPrint('🔐 [MainScreen] Platform: ${Platform.isIOS ? "iOS" : "Android"}');

    final micStatus = await Permission.microphone.status;
    debugPrint('🔐 [MainScreen] Microphone: ${micStatus.name}');

    setState(() {
      _micPermissionStatus = micStatus;
    });

    debugPrint('🔐 [MainScreen] Permission status updated');

    // If microphone is granted, try to initialize VoiceService
    // This will trigger iOS speech permission dialog if not yet granted
    if (micStatus.isGranted && !_voiceService.isInitialized) {
      debugPrint('🎙️ [MainScreen] Microphone granted, initializing VoiceService...');
      final initialized = await _voiceService.initialize();
      debugPrint('🎙️ [MainScreen] VoiceService initialized: $initialized');

      if (!initialized) {
        debugPrint('⚠️ [MainScreen] VoiceService initialization failed');
        setState(() {
          _voiceServiceInitFailed = true;
        });
      } else {
        setState(() {
          _voiceServiceInitFailed = false;
        });
      }
    }
  }

  bool _hasRequiredPermissions() {
    if (_micPermissionStatus == null) return false;
    return _micPermissionStatus!.isGranted && _voiceService.isInitialized;
  }

  bool _shouldShowDisabled() {
    if (_micPermissionStatus == null) return false;
    return _micPermissionStatus!.isPermanentlyDenied || _voiceServiceInitFailed;
  }

  Future<void> _requestPermission() async {
    debugPrint('🔐 [MainScreen] Requesting permission...');
    debugPrint('🔐 [MainScreen] Platform: ${Platform.isIOS ? "iOS" : "Android"}');

    final shouldRequest = await _showPermissionRationale();
    if (!shouldRequest || !mounted) {
      debugPrint('❌ [MainScreen] User declined permission rationale');
      return;
    }

    debugPrint('🔐 [MainScreen] User accepted rationale, requesting microphone permission...');

    final micStatus = await Permission.microphone.request();
    debugPrint('🔐 [MainScreen] Microphone result: ${micStatus.name}');

    if (mounted) {
      await _checkPermissionStatus();
    }
  }

  Future<void> _startRecording() async {
    debugPrint('🎤 [MainScreen] Starting recording...');

    final hasPermission = _hasRequiredPermissions();
    if (!hasPermission) {
      debugPrint('❌ [MainScreen] Cannot record - permissions not granted');
      return;
    }

    if (!mounted) return;
    final configProvider = context.read<AppConfigProvider>();
    final language = configProvider.language;

    setState(() {
      _isRecording = true;
      _recognizedText = '';
    });

    _listeningTextController.repeat(reverse: true);
    _swipeTextController.repeat(reverse: true);

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
      _listeningTextController.stop();
      _swipeTextController.stop();

      setState(() {
        _isRecording = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('voice.error')),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    debugPrint('🛑 [MainScreen] Stopping recording...');
    await _voiceService.stopListening();

    _listeningTextController.stop();
    _swipeTextController.stop();

    setState(() {
      _isRecording = false;
    });

    if (_recognizedText.isNotEmpty) {
      _processExpense(_recognizedText);
    }
  }

  Future<void> _cancelRecording() async {
    debugPrint('❌ [MainScreen] Canceling recording...');
    await _voiceService.cancelListening();

    _listeningTextController.stop();
    _swipeTextController.stop();

    setState(() {
      _isRecording = false;
      _recognizedText = '';
    });
  }

  Future<void> _processExpense(String input) async {
    debugPrint('💰 [MainScreen] Processing expense: "$input"');

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
                  context.tr('home.parsing_expense'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final expenseProvider = context.read<ExpenseProvider>();
      final results = await ExpenseParser.parse(
        input,
        expenseProvider.currentUserId,
      );
      if (mounted) Navigator.pop(context);

      if (results.isEmpty || !results.any((r) => r.success)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('home.parse_failed')),
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
      debugPrint('❌ [MainScreen] Error: $e');
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
              ? context.tr('home.expenses_parsed_multiple', namedArgs: {'count': results.length.toString()})
              : context.tr('home.expense_parsed_single'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < results.length; i++) ...[
                if (results.length > 1) ...[
                  Text(
                    context.tr('home.expense_number', namedArgs: {'number': (i + 1).toString()}),
                    style: Theme.of(context).textTheme.titleMedium,
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
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => _saveExpenses(results),
            child: Text(context.tr('common.save')),
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
        Text('${context.tr('home.amount')}: ${expense.getFormattedAmount()}'),
        Text('${context.tr('home.description')}: ${expense.description}'),
        Text('${context.tr('home.category')}: ${expense.category.toString().split('.').last}'),
        if (result.overallConfidence != null && result.overallConfidence! < 0.7)
          Text(
            '\n${context.tr('home.low_confidence_verify')}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.warning),
          ),
      ],
    );
  }

  Future<void> _saveExpenses(List<ParseResult> results) async {
    debugPrint(
      '💾 [MainScreen] Save button pressed, saving ${results.length} result(s)',
    );

    if (!mounted) return;
    final expenseProvider = context.read<ExpenseProvider>();

    try {
      final expenses = results
          .where((r) => r.success && r.expense != null)
          .map((r) => r.expense!)
          .toList();

      debugPrint(
        '💾 [MainScreen] Filtered to ${expenses.length} valid expense(s)',
      );

      await expenseProvider.addExpenses(expenses);

      debugPrint('✅ [MainScreen] Expenses saved successfully');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              expenses.length > 1
                  ? context.tr('home.expenses_saved_multiple', namedArgs: {'count': expenses.length.toString()})
                  : context.tr('home.expense_saved_single'),
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [MainScreen] Error saving expenses: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('home.error_saving_expenses', namedArgs: {'error': e.toString()})),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<bool> _showPermissionRationale() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.mic, color: AppTheme.info),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Text(
                Platform.isIOS
                    ? context.tr('voice.permission_title_ios')
                    : context.tr('voice.permission_title_android'),
              ),
            ),
          ],
        ),
        content: Text(
          Platform.isIOS
              ? context.tr('voice.permission_rationale_ios')
              : context.tr('voice.permission_rationale_android'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('common.allow')),
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
            Expanded(
              child: Text(context.tr('voice.permission_denied_title')),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Platform.isIOS
                  ? context.tr('voice.permission_denied_message_ios')
                  : context.tr('voice.permission_denied_message_android'),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.1),
                borderRadius: AppTheme.borderRadiusSmall,
                border: Border.all(
                  color: AppTheme.info.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.info, size: 20),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: Text(
                      Platform.isIOS
                          ? context.tr('voice.permission_settings_hint_ios')
                          : context.tr('voice.permission_settings_hint_android'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.info,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
              if (mounted) {
                await _checkPermissionStatus();
              }
            },
            icon: const Icon(Icons.settings),
            label: Text(context.tr('voice.open_settings')),
          ),
        ],
      ),
    );
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content with tabs
          Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
              ),
              // Bottom navigation
              NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: _onTabTapped,
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.add_circle_outline),
                    selectedIcon: const Icon(Icons.add_circle),
                    label: context.tr('navigation.input'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.bar_chart_outlined),
                    selectedIcon: const Icon(Icons.bar_chart),
                    label: context.tr('navigation.report'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.settings_outlined),
                    selectedIcon: const Icon(Icons.settings),
                    label: context.tr('navigation.settings'),
                  ),
                ],
              ),
            ],
          ),

          // Full-screen recording overlay (covers everything including bottom nav)
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
                    AnimatedBuilder(
                      animation: _listeningFadeAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _listeningFadeAnimation.value,
                          child: Text(
                            context.tr('voice.listening'),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        );
                      },
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
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTheme.spacing32),
                    AnimatedBuilder(
                      animation: _swipeSlideAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _swipeSlideAnimation.value),
                          child: Opacity(
                            opacity: 0.7 + (_listeningFadeAnimation.value * 0.3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_upward,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  size: 20,
                                ),
                                const SizedBox(width: AppTheme.spacing8),
                                Text(
                                  context.tr('voice.slide_to_cancel'),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Voice FAB positioned on the left above bottom nav
          Positioned(
            left: AppTheme.spacing16,
            bottom: AppTheme.spacing16 + 80, // 80 is approximate height of NavigationBar
            child: _buildVoiceFAB(),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceFAB() {
    final String buttonText;
    final IconData buttonIcon;
    final Gradient buttonGradient;
    final VoidCallback? onTapAction;
    final bool enableHold;

    if (_isRecording) {
      buttonText = context.tr('home.recording');
      buttonIcon = Icons.mic;
      buttonGradient = AppTheme.accentGradient;
      onTapAction = null;
      enableHold = true;
    } else if (_hasRequiredPermissions()) {
      buttonText = context.tr('voice.hold_to_record');
      buttonIcon = Icons.mic_none;
      buttonGradient = AppTheme.primaryGradient;
      onTapAction = () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('voice.hold_instruction')),
            duration: const Duration(seconds: 2),
          ),
        );
      };
      enableHold = true;
    } else if (_shouldShowDisabled()) {
      buttonText = context.tr('voice.voice_disabled');
      buttonIcon = Icons.mic_off;
      buttonGradient = LinearGradient(
        colors: [AppTheme.error, AppTheme.error.withValues(alpha: 0.8)],
      );
      onTapAction = _showPermissionDeniedDialog;
      enableHold = false;
    } else {
      buttonText = context.tr('voice.tap_to_enable');
      buttonIcon = Icons.mic_off;
      buttonGradient = AppTheme.primaryGradient;
      onTapAction = _requestPermission;
      enableHold = false;
    }

    return GestureDetector(
      onLongPressStart: enableHold && !_isRecording ? (_) => _startRecording() : null,
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
          gradient: buttonGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: AppTheme.shadowLarge,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTapAction,
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
                    buttonIcon,
                    color: Colors.white,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    buttonText,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
}

/// Observer for app lifecycle changes
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onResume;

  _AppLifecycleObserver({required this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}
