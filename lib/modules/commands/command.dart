/// Result of executing a command.
class CommandResult {
  /// Create a successful result with optional message.
  const CommandResult.success([this.message]) : success = true, error = null;

  /// Create a failure result with error message.
  const CommandResult.error(this.error) : success = false, message = null;

  /// Whether the command executed successfully.
  final bool success;

  /// Optional success message to display.
  final String? message;

  /// Error message if the command failed.
  final String? error;

  @override
  String toString() {
    if (success) {
      return 'CommandResult.success(${message ?? ''})';
    }
    return 'CommandResult.error($error)';
  }
}

/// Context provided to commands during execution.
class CommandContext {
  const CommandContext({
    required this.agentId,
    required this.workingDirectory,
    this.sendMessage,
    this.clearConversation,
    this.exitApp,
  });

  /// The ID of the agent in whose context the command is executing.
  final String agentId;

  /// The current working directory.
  final String workingDirectory;

  /// Callback to send a message to the Claude client.
  /// Used by commands that need to interact with Claude (e.g., /compact).
  final void Function(String message)? sendMessage;

  /// Callback to clear the conversation history.
  /// Used by /clear command.
  final Future<void> Function()? clearConversation;

  /// Callback to exit the application.
  /// Used by /exit command.
  final void Function()? exitApp;
}

/// Base interface for all slash commands.
///
/// Commands are invoked when users type `/commandName [arguments]` in the chat.
abstract class Command {
  /// The command name without the leading slash (e.g., "compact", "help").
  String get name;

  /// Short description of what the command does (shown in /help).
  String get description;

  /// Usage example (e.g., "/compact [instructions]").
  String get usage;

  /// Execute the command with optional arguments.
  ///
  /// [context] provides information about the current agent and environment.
  /// [arguments] is the text after the command name (may be null or empty).
  ///
  /// Returns a [CommandResult] indicating success or failure.
  Future<CommandResult> execute(CommandContext context, String? arguments);
}
