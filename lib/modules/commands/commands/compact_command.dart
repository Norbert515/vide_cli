import '../command.dart';

/// Triggers conversation compaction to reduce context usage.
///
/// Compaction summarizes the conversation history to free up context window
/// space while preserving key information.
class CompactCommand extends Command {
  @override
  String get name => 'compact';

  @override
  String get description => 'Compact the conversation to reduce context usage';

  @override
  String get usage => '/compact [custom instructions]';

  @override
  Future<CommandResult> execute(CommandContext context, String? arguments) async {
    // TODO: Implement actual compaction by sending to ClaudeClient
    // For now, return a placeholder message indicating the command was received

    final instructionsNote = arguments != null
        ? ' with instructions: "$arguments"'
        : '';

    return CommandResult.success(
      'Compaction triggered for agent ${context.agentId}$instructionsNote. '
      '(Full implementation pending)',
    );
  }
}
