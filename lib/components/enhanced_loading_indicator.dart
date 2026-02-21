import 'dart:math';
import 'package:agent_sdk/agent_sdk.dart';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';
import 'package:vide_core/vide_core.dart';

class EnhancedLoadingIndicator extends StatefulComponent {
  const EnhancedLoadingIndicator({super.key, this.agentId});

  /// Optional agent ID to show status-aware loading messages.
  /// If provided, the indicator will show messages based on Claude's actual status.
  final String? agentId;

  @override
  State<EnhancedLoadingIndicator> createState() =>
      _EnhancedLoadingIndicatorState();
}

class _EnhancedLoadingIndicatorState extends State<EnhancedLoadingIndicator>
    with TickerProviderStateMixin {
  static final _activities = [
    'Calibrating quantum flux capacitors',
    'Teaching neurons to dance',
    'Counting electrons backwards',
    'Negotiating with the GPU',
    'Consulting the ancient scrolls',
    'Reticulating splines',
    'Downloading more RAM',
    'Asking the rubber duck for advice',
    'Warming up the hamster wheel',
    'Aligning chakras with CPU cores',
    'Bribing the cache',
    'Summoning the algorithm spirits',
    'Untangling virtual spaghetti',
    'Polishing the bits',
    'Feeding the neural network',
    'Optimizing the optimization',
    'Reversing entropy temporarily',
    'Borrowing cycles from the future',
    'Debugging the debugger',
    'Compiling thoughts into words',
    'Defragmenting consciousness',
    'Garbage collecting bad ideas',
    'Spinning up the thinking wheels',
    'Caffeinating the processors',
    'Consulting my digital crystal ball',
    'Performing ritual sacrifices to the memory gods',
    'Translating binary to feelings',
    'Mining for the perfect response',
    'Charging up the synaptic batteries',
    'Dusting off old neural pathways',
    'Waking up sleeping threads',
    'Organizing the chaos matrix',
    'Calibrating sarcasm levels',
    'Loading witty responses',
    'Searching the void for answers',
    'Petting the server hamsters',
    'Adjusting reality parameters',
    'Synchronizing with the cosmos',
    'Downloading wisdom from the cloud',
    'Recursively thinking about thinking',
    'Contemplating the meaning of bits',
    'Herding digital cats',
    'Shaking the magic 8-ball',
    'Tickling the silicon',
    'Whispering sweet nothings to the ALU',
    'Parsing the unparseable',
    'Finding the missing semicolon',
    'Dividing by zero carefully',
    'Counting to infinity twice',
    'Unscrambling quantum eggs',
  ];

  /// Status-specific messages shown when we know the agent's actual state
  static const _statusMessages = {
    AgentProcessingStatus.processing: 'Processing',
    AgentProcessingStatus.thinking: 'Thinking',
    AgentProcessingStatus.responding: 'Responding',
  };

  static final _brailleFrames = [
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏',
  ];

  final _random = Random();
  late AnimationController _spinnerController;
  late AnimationController _activityController;
  int _activityIndex = 0;

  /// Derive braille frame index from animation controller value (0.0-1.0)
  int get _frameIndex =>
      (_spinnerController.value * _brailleFrames.length).floor() %
      _brailleFrames.length;

  /// Derive shimmer position from animation controller, cycling through activity text
  int get _shimmerPosition {
    final textLength =
        _activities[_activityIndex].length + 10; // +10 for padding
    final pos = (_spinnerController.value * textLength).floor() - 5;
    return pos;
  }

  @override
  void initState() {
    super.initState();
    _activityIndex = _random.nextInt(_activities.length);

    // Animation controller for braille spinner and shimmer effect
    // Duration of 1 second gives smooth animation through all frames
    _spinnerController =
        AnimationController(duration: const Duration(seconds: 1), vsync: this)
          ..addListener(() => setState(() {}))
          ..repeat();

    // Activity change controller - cycles through fun messages every 4 seconds
    _activityController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _activityController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _activityIndex = _random.nextInt(_activities.length);
        });
        _activityController.forward(from: 0);
      }
    });
    _activityController.forward();
  }

  @override
  void dispose() {
    _spinnerController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  /// Get the display text based on the agent's processing status.
  /// Shows status prefix when available, otherwise just the fun activity.
  String _getDisplayText(AgentProcessingStatus? status) {
    final activity = _activities[_activityIndex];

    // If we have a meaningful status, show it as a prefix
    if (status != null && _statusMessages.containsKey(status)) {
      return '${_statusMessages[status]}: $activity';
    }

    // Fallback to just the activity
    return activity;
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final braille = _brailleFrames[_frameIndex];

    // Get agent processing status if agent ID is provided
    AgentProcessingStatus? processingStatus;
    if (component.agentId != null) {
      final statusAsync = context.watch(
        agentProcessingStatusProvider(component.agentId!),
      );
      processingStatus = statusAsync.valueOrNull;
    }

    final displayText = _getDisplayText(processingStatus);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Braille spinner
        Text(
          braille,
          style: TextStyle(
            color: theme.base.onSurface.withOpacity(TextOpacity.secondary),
          ),
        ),
        SizedBox(width: 1),
        // Activity text with shimmer
        _buildShimmerText(context, displayText),
      ],
    );
  }

  Component _buildShimmerText(BuildContext context, String text) {
    final theme = VideTheme.of(context);
    final components = <Component>[];

    for (int i = 0; i < text.length; i++) {
      Color color;

      // Single letter shimmer effect
      if (i == _shimmerPosition) {
        color = theme.base.onSurface;
      } else {
        color = theme.base.onSurface.withOpacity(TextOpacity.secondary);
      }

      components.add(Text(text[i], style: TextStyle(color: color)));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: components);
  }
}
