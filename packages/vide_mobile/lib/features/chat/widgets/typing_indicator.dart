import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/vide_colors.dart';

/// The same fun loading messages used in the TUI's EnhancedLoadingIndicator.
const loadingMessages = [
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

/// Animated typing indicator shown at the bottom of the message list
/// when an agent is actively working.
///
/// Displays a braille spinner and a rotating funny message, matching the
/// TUI's EnhancedLoadingIndicator behavior.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  static const _brailleFrames = [
    '\u280B',
    '\u2819',
    '\u2839',
    '\u2838',
    '\u283C',
    '\u2834',
    '\u2826',
    '\u2827',
    '\u2807',
    '\u280F',
  ];

  static const _messageRotationDuration = Duration(seconds: 4);

  final _random = Random();
  late AnimationController _spinnerController;
  late int _messageIndex;

  @override
  void initState() {
    super.initState();
    _messageIndex = _random.nextInt(loadingMessages.length);
    _spinnerController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    _startMessageRotation();
  }

  void _startMessageRotation() {
    Future.delayed(_messageRotationDuration, () {
      if (!mounted) return;
      setState(() {
        _messageIndex = _random.nextInt(loadingMessages.length);
      });
      _startMessageRotation();
    });
  }

  @override
  void dispose() {
    _spinnerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videColors = Theme.of(context).extension<VideThemeColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VideSpacing.sm,
        vertical: VideSpacing.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: AnimatedBuilder(
          animation: _spinnerController,
          builder: (context, child) {
            final frameIndex =
                (_spinnerController.value * _brailleFrames.length).floor() %
                    _brailleFrames.length;
            return Row(
              children: [
                Text(
                  _brailleFrames[frameIndex],
                  style: TextStyle(
                    fontSize: 14,
                    color: videColors.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: VideDurations.normal,
                    child: Text(
                      loadingMessages[_messageIndex],
                      key: ValueKey(_messageIndex),
                      style: TextStyle(
                        fontSize: 13,
                        color: videColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
