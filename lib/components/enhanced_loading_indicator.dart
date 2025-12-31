import 'dart:async';
import 'dart:math';
import 'package:nocterm/nocterm.dart';
import 'package:vide_cli/constants/text_opacity.dart';
import 'package:vide_cli/theme/theme.dart';

class EnhancedLoadingIndicator extends StatefulComponent {
  const EnhancedLoadingIndicator({super.key});

  @override
  State<EnhancedLoadingIndicator> createState() =>
      _EnhancedLoadingIndicatorState();
}

class _EnhancedLoadingIndicatorState extends State<EnhancedLoadingIndicator> {
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
  Timer? _animationTimer;
  Timer? _activityTimer;
  int _frameIndex = 0;
  int _activityIndex = 0;
  int _shimmerPosition = 0;

  @override
  void initState() {
    super.initState();
    _activityIndex = _random.nextInt(_activities.length);

    // Animation timer for braille and shimmer
    _animationTimer = Timer.periodic(Duration(milliseconds: 100), (_) {
      setState(() {
        _frameIndex = (_frameIndex + 1) % _brailleFrames.length;
        _shimmerPosition = (_shimmerPosition + 1);
        if (_shimmerPosition >= _activities[_activityIndex].length + 5) {
          _shimmerPosition = -5;
        }
      });
    });

    // Activity change timer
    _activityTimer = Timer.periodic(Duration(seconds: 4), (_) {
      setState(() {
        _activityIndex = _random.nextInt(_activities.length);
        _shimmerPosition = -5;
      });
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _activityTimer?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final theme = VideTheme.of(context);
    final braille = _brailleFrames[_frameIndex];
    final activity = _activities[_activityIndex];

    return Row(
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
        _buildShimmerText(context, activity),
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
