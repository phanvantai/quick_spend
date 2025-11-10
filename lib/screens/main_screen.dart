import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quick_spend/models/expense.dart';
import '../providers/app_config_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import '../services/voice_service.dart';
import '../services/expense_parser.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/voice_tutorial_overlay.dart';
import 'home_screen.dart';
import 'report_screen.dart';

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
  bool _isSwiping = false; // Track if user is swiping to cancel
  double _soundLevel = 0.0;
  String _recognizedText = '';
  PermissionStatus? _micPermissionStatus;
  bool _voiceServiceInitFailed = false;
  late AnimationController _listeningTextController;
  late AnimationController _swipeTextController;
  late Animation<double> _listeningFadeAnimation;
  late Animation<double> _swipeSlideAnimation;
  late WidgetsBindingObserver _lifecycleObserver;

  // Tutorial state
  final PreferencesService _prefsService = PreferencesService();
  bool _showTutorial = false;
  bool _shouldShowPulse = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final GlobalKey _fabKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _screens = [const HomeScreen(), const ReportScreen()];

    // Check tutorial status first (show immediately on first launch)
    _checkTutorialStatus();

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
      CurvedAnimation(parent: _swipeTextController, curve: Curves.easeInOut),
    );

    // Pulse animation for tutorial hint
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _listeningTextController.dispose();
    _swipeTextController.dispose();
    _pulseController.dispose();
    _voiceService.dispose();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  Future<void> _checkPermissionStatus() async {
    debugPrint('🔐 [MainScreen] Checking permission status...');
    debugPrint(
      '🔐 [MainScreen] Platform: ${Platform.isIOS ? "iOS" : "Android"}',
    );

    final micStatus = await Permission.microphone.status;
    debugPrint('🔐 [MainScreen] Microphone: ${micStatus.name}');

    setState(() {
      _micPermissionStatus = micStatus;
    });

    debugPrint('🔐 [MainScreen] Permission status updated');

    // If microphone is granted, try to initialize VoiceService
    // This will trigger iOS speech permission dialog if not yet granted
    if (micStatus.isGranted && !_voiceService.isInitialized) {
      debugPrint(
        '🎙️ [MainScreen] Microphone granted, initializing VoiceService...',
      );
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

  Future<void> _checkTutorialStatus() async {
    debugPrint('📚 [MainScreen] Checking tutorial status...');
    final hasShown = await _prefsService.hasShownVoiceTutorial();

    debugPrint('📚 [MainScreen] Tutorial shown: $hasShown');

    if (!hasShown) {
      // Show tutorial immediately on first launch
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() {
          _showTutorial = true;
        });
      }
    } else {
      // Always show pulsing hint after tutorial is dismissed
      setState(() {
        _shouldShowPulse = true;
      });
      _pulseController.repeat(reverse: true);
    }
  }

  Future<void> _dismissTutorial() async {
    debugPrint('📚 [MainScreen] Dismissing tutorial...');
    await _prefsService.markVoiceTutorialShown();

    setState(() {
      _showTutorial = false;
      _shouldShowPulse = true;
    });

    // Start pulsing animation for next few uses
    _pulseController.repeat(reverse: true);
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
    debugPrint(
      '🔐 [MainScreen] Platform: ${Platform.isIOS ? "iOS" : "Android"}',
    );

    final shouldRequest = await _showPermissionRationale();
    if (!shouldRequest || !mounted) {
      debugPrint('❌ [MainScreen] User declined permission rationale');
      return;
    }

    debugPrint(
      '🔐 [MainScreen] User accepted rationale, requesting microphone permission...',
    );

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
      _isSwiping = false;
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
      _isSwiping = false;
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
      final categoryProvider = context.read<CategoryProvider>();
      final results = await ExpenseParser.parse(
        input,
        expenseProvider.currentUserId,
        categoryProvider.categories,
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
          SnackBar(
            content: Text(
              context.tr('common.error', namedArgs: {'error': e.toString()}),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showExpenseResultsDialog(List<ParseResult> results) {
    showDialog(
      context: context,
      builder: (context) => _EditableExpenseDialog(results: results),
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
            Expanded(child: Text(context.tr('voice.permission_denied_title'))),
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
                border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.info,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: Text(
                      Platform.isIOS
                          ? context.tr('voice.permission_settings_hint_ios')
                          : context.tr(
                              'voice.permission_settings_hint_android',
                            ),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppTheme.info),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Main Scaffold with content and bottom navigation
        Scaffold(
          extendBody: true,
          body: IndexedStack(index: _currentIndex, children: _screens),
          // Notched BottomAppBar with navigation items
          bottomNavigationBar: BottomAppBar(
            color: Colors.transparent,
            elevation: 0,
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                LiquidGlassLayer(
                  child: LiquidGlass(
                    shape: LiquidRoundedSuperellipse(borderRadius: 30),
                    child: IconButton(
                      icon: Icon(
                        _currentIndex == 0 ? Icons.home : Icons.home_outlined,
                      ),
                      color: _currentIndex == 0
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      onPressed: () => _onTabTapped(0),
                      tooltip: context.tr('navigation.home'),
                    ),
                  ),
                ),
                const SizedBox(width: 48), // Space for the FAB
                LiquidGlassLayer(
                  child: LiquidGlass(
                    shape: LiquidRoundedSuperellipse(borderRadius: 30),
                    child: IconButton(
                      icon: Icon(
                        _currentIndex == 1
                            ? Icons.bar_chart
                            : Icons.bar_chart_outlined,
                      ),
                      color: _currentIndex == 1
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      onPressed: () => _onTabTapped(1),
                      tooltip: context.tr('navigation.report'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Voice FAB docked in the center
          floatingActionButton: _buildVoiceFAB(),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.miniCenterDocked,
        ),

        // Full-screen recording overlay (covers everything including bottom nav and FAB)
        if (_isRecording)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerUp: (_) {
                debugPrint(
                  '👆 [MainScreen] Pointer UP detected, _isSwiping: $_isSwiping',
                );
                // Only stop recording if user didn't swipe to cancel
                if (!_isSwiping) {
                  _stopRecording();
                }
                // Reset swipe flag
                setState(() {
                  _isSwiping = false;
                });
              },
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.primaryDelta! < -10) {
                    debugPrint('👆 [MainScreen] Swipe up detected - canceling');
                    setState(() {
                      _isSwiping = true;
                    });
                    _cancelRecording();
                  }
                },
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
                      // Tap to stop instruction
                      AnimatedBuilder(
                        animation: _listeningFadeAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity:
                                0.7 + (_listeningFadeAnimation.value * 0.3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.touch_app,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  size: 20,
                                ),
                                const SizedBox(width: AppTheme.spacing8),
                                Text(
                                  context.tr('voice.tap_to_stop'),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      // Swipe to cancel instruction
                      AnimatedBuilder(
                        animation: _swipeSlideAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _swipeSlideAnimation.value),
                            child: Opacity(
                              opacity:
                                  0.7 + (_listeningFadeAnimation.value * 0.3),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
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
            ),
          ),

        // Tutorial overlay
        if (_showTutorial)
          VoiceTutorialOverlay(
            onDismiss: _dismissTutorial,
            fabPosition: _getFABPosition(),
          ),
      ],
    );
  }

  Offset _getFABPosition() {
    // Get actual FAB position from its RenderBox
    try {
      final RenderBox? renderBox =
          _fabKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        // Return the center of the FAB
        return Offset(
          position.dx + size.width / 2,
          position.dy + size.height / 2,
        );
      }
    } catch (e) {
      debugPrint('⚠️ [MainScreen] Could not get FAB position: $e');
    }

    // Fallback to approximation if RenderBox not available yet
    final size = MediaQuery.of(context).size;
    return Offset(size.width / 2, size.height - 80);
  }

  Widget _buildVoiceFAB() {
    final IconData buttonIcon;
    final Gradient buttonGradient;
    final VoidCallback? onTapAction;

    if (_isRecording) {
      // Recording: tap to stop
      buttonIcon = Icons.mic;
      buttonGradient = AppTheme.accentGradient;
      onTapAction = () {
        debugPrint('👆 [MainScreen] Tap to stop recording');
        _stopRecording();
      };
    } else if (_hasRequiredPermissions()) {
      // Ready: tap to start recording
      buttonIcon = Icons.mic_none;
      buttonGradient = AppTheme.accentGradient;
      onTapAction = () {
        debugPrint('👆 [MainScreen] Tap to start recording');
        _startRecording();
      };
    } else if (_shouldShowDisabled()) {
      // Permission denied: tap to show dialog
      buttonIcon = Icons.mic_off;
      buttonGradient = LinearGradient(
        colors: [AppTheme.error, AppTheme.error.withValues(alpha: 0.8)],
      );
      onTapAction = _showPermissionDeniedDialog;
    } else {
      // No permission yet: tap to request
      buttonIcon = Icons.mic_off;
      buttonGradient = AppTheme.accentGradient;
      onTapAction = _requestPermission;
    }

    final fabWidget = LiquidGlassLayer(
      child: LiquidGlass(
        shape: LiquidRoundedSuperellipse(borderRadius: 60),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: buttonGradient.withOpacity(0.5),
            shape: BoxShape.circle,
            boxShadow: AppTheme.shadowLarge,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTapAction,
              customBorder: const CircleBorder(),
              child: Icon(buttonIcon, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
    );

    // Wrap with pulsing rings if needed
    final Widget result;
    if (_shouldShowPulse && !_isRecording) {
      result = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring
              Container(
                width: 72 * _pulseAnimation.value * 1.2,
                height: 72 * _pulseAnimation.value * 1.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accentPink.withValues(
                      alpha: 0.3 * (2 - _pulseAnimation.value),
                    ),
                    width: 2,
                  ),
                ),
              ),
              // Inner ring
              Container(
                width: 72 * _pulseAnimation.value,
                height: 72 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accentOrange.withValues(
                      alpha: 0.4 * (2 - _pulseAnimation.value),
                    ),
                    width: 2,
                  ),
                ),
              ),
              // FAB
              child!,
            ],
          );
        },
        child: fabWidget,
      );
    } else {
      result = fabWidget;
    }

    // Wrap entire FAB with key for position tracking
    return Container(key: _fabKey, child: result);
  }

  Widget _buildRipple(double level, double size, double opacity) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
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

/// Editable expense confirmation dialog
class _EditableExpenseDialog extends StatefulWidget {
  final List<ParseResult> results;

  const _EditableExpenseDialog({required this.results});

  @override
  State<_EditableExpenseDialog> createState() => _EditableExpenseDialogState();
}

class _EditableExpenseDialogState extends State<_EditableExpenseDialog> {
  late List<_ExpenseFormData> _expenseForms;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Initialize form data from parsed results
    _expenseForms = widget.results
        .map((r) => _ExpenseFormData.fromExpense(r.expense!))
        .toList();
  }

  Future<void> _saveExpenses() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    debugPrint(
      '💾 [EditableExpenseDialog] Saving ${_expenseForms.length} expense(s)',
    );

    if (!mounted) return;
    final expenseProvider = context.read<ExpenseProvider>();

    try {
      final expenses = _expenseForms.map((form) => form.toExpense()).toList();

      await expenseProvider.addExpenses(expenses);

      debugPrint('✅ [EditableExpenseDialog] Expenses saved successfully');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              expenses.length > 1
                  ? context.tr(
                      'home.expenses_saved_multiple',
                      namedArgs: {'count': expenses.length.toString()},
                    )
                  : context.tr('home.expense_saved_single'),
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [EditableExpenseDialog] Error saving expenses: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'home.error_saving_expenses',
                namedArgs: {'error': e.toString()},
              ),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _expenseForms.length > 1
            ? context.tr(
                'home.expenses_parsed_multiple',
                namedArgs: {'count': _expenseForms.length.toString()},
              )
            : context.tr('home.expense_parsed_single'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _expenseForms.length; i++) ...[
                if (_expenseForms.length > 1) ...[
                  Text(
                    context.tr(
                      'home.expense_number',
                      namedArgs: {'number': (i + 1).toString()},
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                ],
                _ExpenseFormCard(
                  formData: _expenseForms[i],
                  onChanged: () => setState(() {}),
                ),
                if (i < _expenseForms.length - 1) ...[
                  const Divider(height: AppTheme.spacing24),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton.icon(
          onPressed: _saveExpenses,
          icon: const Icon(Icons.check),
          label: Text(context.tr('common.save')),
        ),
      ],
    );
  }
}

/// Form card for editing a single expense
class _ExpenseFormCard extends StatelessWidget {
  final _ExpenseFormData formData;
  final VoidCallback onChanged;

  const _ExpenseFormCard({required this.formData, required this.onChanged});

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: formData.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && picked != formData.date) {
      formData.date = picked;
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final appConfig = context.watch<AppConfigProvider>().config;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Description field
        TextFormField(
          initialValue: formData.description,
          decoration: InputDecoration(
            labelText: context.tr('home.description'),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.description_outlined),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return context.tr('home.description_required');
            }
            return null;
          },
          onSaved: (value) => formData.description = value!.trim(),
        ),
        const SizedBox(height: AppTheme.spacing12),

        // Amount field
        TextFormField(
          initialValue: formData.amount.toString(),
          decoration: InputDecoration(
            labelText: context.tr('home.amount'),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.attach_money),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return context.tr('home.amount_required');
            }
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
              return context.tr('home.amount_invalid');
            }
            return null;
          },
          onSaved: (value) => formData.amount = double.parse(value!),
        ),
        const SizedBox(height: AppTheme.spacing12),

        // Category selector
        DropdownButtonFormField<String>(
          initialValue: formData.categoryId,
          decoration: InputDecoration(
            labelText: context.tr('home.category'),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.category_outlined),
          ),
          items: categoryProvider.categories.map((cat) {
            return DropdownMenuItem(
              value: cat.id,
              child: Row(
                children: [
                  Icon(cat.icon, color: cat.color, size: 20),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(cat.getLabel(appConfig.language)),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              formData.categoryId = value;
              onChanged();
            }
          },
        ),
        const SizedBox(height: AppTheme.spacing12),

        // Date selector
        InkWell(
          onTap: () => _selectDate(context),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: context.tr('home.date'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.calendar_today),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              DateFormat.yMMMd().format(formData.date),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),

        // Low confidence warning
        if (formData.confidence < 0.7) ...[
          const SizedBox(height: AppTheme.spacing12),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.15),
              borderRadius: AppTheme.borderRadiusSmall,
              border: Border.all(
                color: AppTheme.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_outlined,
                  color: AppTheme.warning,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    context.tr('home.low_confidence_verify'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.warning),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Data class to hold expense form data
class _ExpenseFormData {
  String id;
  String description;
  double amount;
  String categoryId;
  String language;
  DateTime date;
  String userId;
  String rawInput;
  double confidence;
  TransactionType type;

  _ExpenseFormData({
    required this.id,
    required this.description,
    required this.amount,
    required this.categoryId,
    required this.language,
    required this.date,
    required this.userId,
    required this.rawInput,
    required this.confidence,
    required this.type,
  });

  factory _ExpenseFormData.fromExpense(Expense expense) {
    return _ExpenseFormData(
      id: expense.id,
      description: expense.description,
      amount: expense.amount,
      categoryId: expense.categoryId,
      language: expense.language,
      date: expense.date,
      userId: expense.userId,
      rawInput: expense.rawInput,
      confidence: expense.confidence,
      type: expense.type,
    );
  }

  Expense toExpense() {
    return Expense(
      id: id,
      description: description,
      amount: amount,
      categoryId: categoryId,
      language: language,
      date: date,
      userId: userId,
      rawInput: rawInput,
      confidence: confidence,
      type: type,
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
