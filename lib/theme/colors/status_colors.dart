import 'package:nocterm/nocterm.dart';

/// Status colors for agent and task states.
///
/// These colors represent the various states that agents and tasks can be in
/// within the Vide agent network.
class VideStatusColors {
  /// Color for an agent that is actively working.
  final Color working;

  /// Color for an agent waiting for a sub-agent to respond.
  final Color waitingForAgent;

  /// Color for an agent waiting for user input.
  final Color waitingForUser;

  /// Color for an agent that is idle/done.
  final Color idle;

  /// Color for a pending task or tool.
  final Color pending;

  /// Color for a task or tool in progress.
  final Color inProgress;

  /// Color for a completed task or tool.
  final Color completed;

  /// Color for an error state.
  final Color error;

  /// Creates a custom status color set.
  const VideStatusColors({
    required this.working,
    required this.waitingForAgent,
    required this.waitingForUser,
    required this.idle,
    required this.pending,
    required this.inProgress,
    required this.completed,
    required this.error,
  });

  /// Dark theme status colors.
  static const VideStatusColors dark = VideStatusColors(
    working: Colors.cyan,
    waitingForAgent: Colors.yellow,
    waitingForUser: Colors.magenta,
    idle: Colors.green,
    pending: Color(0xE5C07B),
    inProgress: Color(0xE5C07B),
    completed: Color(0x98C379),
    error: Color(0xE06C75),
  );

  /// Light theme status colors.
  static const VideStatusColors light = VideStatusColors(
    working: Color(0x008B8B), // dark cyan
    waitingForAgent: Color(0xFF8C00), // dark orange
    waitingForUser: Color(0x8B008B), // dark magenta
    idle: Color(0x228B22), // forest green
    pending: Color(0xDAA520), // goldenrod
    inProgress: Color(0xDAA520), // goldenrod
    completed: Color(0x228B22), // forest green
    error: Color(0xDC143C), // crimson
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideStatusColors &&
        other.working == working &&
        other.waitingForAgent == waitingForAgent &&
        other.waitingForUser == waitingForUser &&
        other.idle == idle &&
        other.pending == pending &&
        other.inProgress == inProgress &&
        other.completed == completed &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(
    working,
    waitingForAgent,
    waitingForUser,
    idle,
    pending,
    inProgress,
    completed,
    error,
  );
}
