import 'dart:async';
import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/modules/agent_network/models/activity_state.dart';
import 'package:vide_cli/modules/agent_network/service/activity_classifier.dart';

class EnhancedLoadingIndicator extends StatefulComponent {
  /// Optional activity state for context-aware messages.
  /// If provided, shows messages based on what the agent is actually doing.
  /// If null, falls back to random funny messages.
  final ActivityState? activityState;

  /// When the current response started (for elapsed time display)
  final DateTime? responseStartTime;

  /// Current output token count (for token counter display)
  final int? outputTokens;

  const EnhancedLoadingIndicator({
    super.key,
    this.activityState,
    this.responseStartTime,
    this.outputTokens,
  });

  @override
  State<EnhancedLoadingIndicator> createState() =>
      _EnhancedLoadingIndicatorState();
}

class _EnhancedLoadingIndicatorState extends State<EnhancedLoadingIndicator> {
  static final _brailleFrames = [
    '\u280b', // ⠋
    '\u2819', // ⠙
    '\u2839', // ⠹
    '\u2838', // ⠸
    '\u283c', // ⠼
    '\u2834', // ⠴
    '\u2826', // ⠦
    '\u2827', // ⠧
    '\u2807', // ⠇
    '\u280f', // ⠏
  ];

  Timer? _animationTimer;
  Timer? _activityTimer;
  int _frameIndex = 0;
  int _shimmerPosition = 0;

  // Fallback message for when no activity state is provided
  String? _fallbackMessage;
  ActivityCategory? _lastCategory;

  @override
  void initState() {
    super.initState();
    _pickFallbackMessage();

    // Animation timer for braille and shimmer
    _animationTimer = Timer.periodic(Duration(milliseconds: 100), (_) {
      setState(() {
        _frameIndex = (_frameIndex + 1) % _brailleFrames.length;
        final currentMessage = _getCurrentMessage();
        _shimmerPosition = (_shimmerPosition + 1);
        if (_shimmerPosition >= currentMessage.length + 5) {
          _shimmerPosition = -5;
        }
      });
    });

    // Activity change timer (only for fallback messages)
    _activityTimer = Timer.periodic(Duration(seconds: 4), (_) {
      if (component.activityState == null) {
        setState(() {
          _pickFallbackMessage();
          _shimmerPosition = -5;
        });
      }
    });
  }

  void _pickFallbackMessage() {
    // Pick from the idle pool for fallback
    _fallbackMessage = ActivityClassifier.getRandomMessageForCategory(ActivityCategory.idle);
  }

  @override
  void didUpdateComponent(EnhancedLoadingIndicator oldComponent) {
    super.didUpdateComponent(oldComponent);

    // When activity category changes, pick a new message for that category
    final newCategory = component.activityState?.activityMessage?.category;
    if (newCategory != null && newCategory != _lastCategory) {
      _lastCategory = newCategory;
      _shimmerPosition = -5; // Reset shimmer for new message
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _activityTimer?.cancel();
    super.dispose();
  }

  String _getCurrentMessage() {
    final state = component.activityState;

    // If we have an activity state with a message, use it
    if (state != null && state.activityMessage != null) {
      return state.activityMessage!.format();
    }

    // If thinking, show thinking message
    if (state != null && state.isThinking) {
      final duration = state.formattedThinkingDuration;
      if (duration != null) {
        return 'Thinking... ($duration)';
      }
      return 'Thinking...';
    }

    // Fallback to random message
    return _fallbackMessage ?? 'Processing...';
  }

  String _formatElapsedTime() {
    if (component.responseStartTime == null) return '';
    final elapsed = DateTime.now().difference(component.responseStartTime!);
    final seconds = elapsed.inSeconds;
    if (seconds < 60) {
      return '${seconds}s';
    } else {
      final minutes = elapsed.inMinutes;
      final remainingSeconds = seconds % 60;
      return '${minutes}m ${remainingSeconds}s';
    }
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000) {
      final k = tokens / 1000;
      return '${k.toStringAsFixed(1)}k';
    }
    return tokens.toString();
  }

  @override
  Component build(BuildContext context) {
    final braille = _brailleFrames[_frameIndex];
    final message = _getCurrentMessage();
    final state = component.activityState;

    // Build the status info parts
    final statusParts = <String>[];

    // Add elapsed time if we have a start time
    if (component.responseStartTime != null) {
      statusParts.add(_formatElapsedTime());
    }

    // Add token count if available
    if (component.outputTokens != null && component.outputTokens! > 0) {
      statusParts.add('\u2193 ${_formatTokens(component.outputTokens!)} tokens');
    }

    return Row(
      children: [
        // Braille spinner
        Text(
          braille,
          style: TextStyle(
            color: Colors.white.withOpacity(TextOpacity.secondary),
          ),
        ),
        SizedBox(width: 1),
        // Activity text with shimmer
        _buildShimmerText(message),
        // Show pending tool count if > 0
        if (state != null && state.pendingToolCount > 0) ...[
          SizedBox(width: 1),
          Text(
            '(+${state.pendingToolCount} more)',
            style: TextStyle(
              color: Colors.white.withOpacity(TextOpacity.tertiary),
            ),
          ),
        ],
        // Show elapsed time and tokens
        if (statusParts.isNotEmpty) ...[
          SizedBox(width: 1),
          Text(
            '(${statusParts.join(' \u00b7 ')})',
            style: TextStyle(
              color: Colors.white.withOpacity(TextOpacity.tertiary),
            ),
          ),
        ],
      ],
    );
  }

  Component _buildShimmerText(String text) {
    final components = <Component>[];

    for (int i = 0; i < text.length; i++) {
      Color color;

      // Single letter shimmer effect
      if (i == _shimmerPosition) {
        color = Colors.white;
      } else {
        color = Colors.white.withOpacity(TextOpacity.secondary);
      }

      components.add(Text(text[i], style: TextStyle(color: color)));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: components);
  }
}

/// A simpler thinking indicator that just shows duration
class ThinkingIndicator extends StatefulComponent {
  final DateTime? startTime;

  const ThinkingIndicator({super.key, this.startTime});

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator> {
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _updateSeconds();
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      setState(() {
        _updateSeconds();
      });
    });
  }

  void _updateSeconds() {
    if (component.startTime != null) {
      _seconds = DateTime.now().difference(component.startTime!).inSeconds;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return Text(
      'Thought for ${_seconds}s',
      style: TextStyle(
        color: Colors.white.withOpacity(TextOpacity.tertiary),
      ),
    );
  }
}
