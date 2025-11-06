import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';

/// Tutorial overlay that teaches users how to use voice input
/// Shows on first launch with animated instructions
class VoiceTutorialOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final Offset fabPosition;

  const VoiceTutorialOverlay({
    super.key,
    required this.onDismiss,
    required this.fabPosition,
  });

  @override
  State<VoiceTutorialOverlay> createState() => _VoiceTutorialOverlayState();
}

class _VoiceTutorialOverlayState extends State<VoiceTutorialOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // Animate hand pressing down and up repeatedly
    _pressAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 20),
    ]).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _animationController.forward();
    // Repeat the press animation
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.forward(from: 0.3);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDismiss,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Container(
            color: Colors.black.withValues(alpha: 0.85 * _fadeAnimation.value),
            child: Stack(
              children: [
                // Spotlight on FAB
                Positioned(
                  left: widget.fabPosition.dx - 60,
                  bottom: widget.fabPosition.dy - 60,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.7 * _fadeAnimation.value),
                          blurRadius: 50,
                          spreadRadius: 50,
                        ),
                      ],
                    ),
                  ),
                ),

                // Instructions at the top
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.2,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Column(
                        children: [
                          Icon(
                            Icons.touch_app,
                            size: 48,
                            color: AppTheme.accentPink,
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          Text(
                            context.tr('voice.tutorial_title'),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppTheme.spacing12),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacing32,
                            ),
                            child: Text(
                              context.tr('voice.tutorial_description'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Animated hand gesture
                Positioned(
                  left: widget.fabPosition.dx + 40,
                  bottom: widget.fabPosition.dy + 40,
                  child: AnimatedBuilder(
                    animation: _pressAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, -10 * _pressAnimation.value),
                        child: Opacity(
                          opacity: 0.3 +
                              (0.7 * _fadeAnimation.value) *
                                  (1 - _pressAnimation.value * 0.3),
                          child: Icon(
                            Icons.touch_app,
                            size: 40,
                            color: AppTheme.accentOrange,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Got it button
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.of(context).size.height * 0.15,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: AppTheme.borderRadiusMedium,
                          boxShadow: AppTheme.shadowLarge,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onDismiss,
                            borderRadius: AppTheme.borderRadiusMedium,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacing32,
                                vertical: AppTheme.spacing16,
                              ),
                              child: Text(
                                context.tr('voice.tutorial_got_it'),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Tap anywhere hint
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.of(context).size.height * 0.08,
                  child: Opacity(
                    opacity: 0.6 * _fadeAnimation.value,
                    child: Text(
                      context.tr('voice.tutorial_tap_anywhere'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
