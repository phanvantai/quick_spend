import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Voice input button with hold-to-record functionality
class VoiceInputButton extends StatefulWidget {
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;
  final bool isRecording;
  final double? soundLevel;

  const VoiceInputButton({
    super.key,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
    this.isRecording = false,
    this.soundLevel,
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isDraggingToCancel = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void didUpdateWidget(VoiceInputButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isRecording) {
      return _buildRecordingState();
    }
    return _buildIdleState();
  }

  Widget _buildIdleState() {
    return GestureDetector(
      onLongPressStart: (_) {
        widget.onStartRecording();
      },
      child: FloatingActionButton.extended(
        onPressed: () {
          // Tap to show help message
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

  Widget _buildRecordingState() {
    return GestureDetector(
      onLongPressEnd: (_) {
        if (_isDraggingToCancel) {
          widget.onCancelRecording();
        } else {
          widget.onStopRecording();
        }
        setState(() {
          _isDraggingToCancel = false;
        });
      },
      onLongPressMoveUpdate: (details) {
        // If user drags up, cancel the recording
        final shouldCancel = details.localOffsetFromOrigin.dy < -50;
        if (shouldCancel != _isDraggingToCancel) {
          setState(() {
            _isDraggingToCancel = shouldCancel;
          });
        }
      },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isDraggingToCancel
                  ? Colors.red
                  : Theme.of(context).colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: (_isDraggingToCancel ? Colors.red : Theme.of(context).colorScheme.primary)
                      .withValues(alpha: 0.3 + (_pulseController.value * 0.3)),
                  blurRadius: 20 + (_pulseController.value * 20),
                  spreadRadius: 5 + (_pulseController.value * 10),
                ),
              ],
            ),
            child: Icon(
              _isDraggingToCancel ? Icons.close : Icons.mic,
              color: Colors.white,
              size: 32,
            ),
          );
        },
      ),
    );
  }
}
