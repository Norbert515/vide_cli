import 'package:claude_sdk/claude_sdk.dart';
import 'package:vide_core/vide_core.dart';

/// Creates a CanUseToolCallback for the REST API using vide_core's PermissionChecker.
///
/// This provides the same security guarantees as the TUI, including:
/// - Safe command detection (git status, ls, etc.)
/// - Dangerous command blocking (rm -rf, sudo, etc.)
/// - Output redirection checks
/// - .gitignore respect for Read operations
/// - Settings file support (.claude/settings.local.json)
///
/// Unlike TUI, REST API cannot prompt users, so [PermissionAskUser] results
/// are converted to deny via [PermissionCheckerConfig.restApi].
CanUseToolCallback createRestPermissionCallback(String cwd) {
  final checker = PermissionChecker(config: PermissionCheckerConfig.restApi);

  return (
    String toolName,
    Map<String, dynamic> rawInput,
    ToolPermissionContext context,
  ) async {
    // Convert raw map to type-safe ToolInput
    final input = ToolInput.fromJson(toolName, rawInput);

    final result = await checker.checkPermission(
      toolName: toolName,
      input: input,
      cwd: cwd,
    );

    // With PermissionCheckerConfig.restApi, PermissionAskUser is never returned
    // (config.askUserBehavior = deny converts it to PermissionDeny)
    return switch (result) {
      PermissionAllow() => const PermissionResultAllow(),
      PermissionDeny(:final reason) => PermissionResultDeny(message: reason),
      PermissionAskUser() => const PermissionResultDeny(
        message:
            'Operation requires user approval (unexpected in REST API mode)',
      ),
    };
  };
}
