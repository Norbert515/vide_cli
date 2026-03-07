import '../command.dart';

/// View or change the effort level for the current agent.
///
/// Usage:
///   /effort          - Show current effort level
///   /effort low      - Faster, shorter responses
///   /effort medium   - Balanced speed and depth
///   /effort high     - Thorough, detailed responses
///   /effort max      - Maximum depth and reasoning
class EffortCommand extends Command {
  static const _validLevels = ['low', 'medium', 'high', 'max'];

  @override
  String get name => 'effort';

  @override
  String get description => 'View or change the effort level';

  @override
  String get usage => '/effort [low|medium|high|max]';

  @override
  Future<CommandResult> execute(
    CommandContext context,
    String? arguments,
  ) async {
    if (context.getClaudeSettings == null ||
        context.applyClaudeSettings == null) {
      return CommandResult.error('No active session');
    }

    // No argument: show current effort
    if (arguments == null || arguments.isEmpty) {
      final settings = await context.getClaudeSettings!();
      final effort = settings?['effortLevel'] as String?;
      return CommandResult.success(
        effort != null
            ? 'Current effort: $effort'
            : 'No effort level explicitly set',
      );
    }

    final effort = arguments.trim().toLowerCase();
    if (!_validLevels.contains(effort)) {
      return CommandResult.error(
        'Invalid effort level: $effort. '
        'Valid levels: ${_validLevels.join(', ')}',
      );
    }

    await context.applyClaudeSettings!({'effortLevel': effort});
    return CommandResult.success('Effort set to: $effort');
  }
}
