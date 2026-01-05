import '../command.dart';

/// Triggers conversation compaction to reduce context usage.
///
/// Compaction summarizes the conversation history to free up context window
/// space while preserving key information.
///
/// This command sends `/compact` to the Claude Code CLI which handles the
/// actual compaction process.
class CompactCommand extends Command {
  @override
  String get name => 'compact';

  @override
  String get description => 'Compact the conversation to reduce context usage';

  @override
  String get usage => '/compact [custom instructions]';

  @override
  Future<CommandResult> execute(
    CommandContext context,
    String? arguments,
  ) async {
    if (context.sendMessage == null) {
      return CommandResult.error(
        'Cannot compact: message sending not available',
      );
    }

    // Build the /compact command with optional instructions
    final compactMessage = arguments != null && arguments.isNotEmpty
        ? '/compact $arguments'
        : '/compact';

    // Send /compact to Claude Code CLI which handles the compaction
    context.sendMessage!(compactMessage);

    return CommandResult.success('Compacting conversation...');
  }
}
