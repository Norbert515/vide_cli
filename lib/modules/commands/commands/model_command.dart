import '../command.dart';

/// View or change the model for the current agent.
///
/// Usage:
///   /model           - Show current model
///   /model sonnet    - Switch to sonnet
///   /model opus      - Switch to opus
///   /model haiku     - Switch to haiku
class ModelCommand extends Command {
  @override
  String get name => 'model';

  @override
  String get description => 'View or change the model';

  @override
  String get usage => '/model [opus|sonnet|haiku]';

  @override
  Future<CommandResult> execute(
    CommandContext context,
    String? arguments,
  ) async {
    if (context.getClaudeSettings == null ||
        context.applyClaudeSettings == null) {
      return CommandResult.error('No active session');
    }

    // No argument: show current model
    if (arguments == null || arguments.isEmpty) {
      final settings = await context.getClaudeSettings!();
      final model = settings?['model'] as String?;
      return CommandResult.success(
        model != null ? 'Current model: $model' : 'No model explicitly set',
      );
    }

    final model = arguments.trim().toLowerCase();
    await context.applyClaudeSettings!({'model': model});
    return CommandResult.success('Model set to: $model');
  }
}
