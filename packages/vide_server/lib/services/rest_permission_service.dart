import 'package:claude_sdk/claude_sdk.dart';
import 'package:vide_core/vide_core.dart';

import 'session_permission_manager.dart';

/// Creates a CanUseToolCallback based on the permission mode in the context.
///
/// This is the main entry point for the REST API's permission callback factory.
/// It decides which callback to use based on the [PermissionCallbackContext.permissionMode]:
///
/// - `ask`: Uses [createInteractivePermissionCallback] to forward requests to the client
/// - `default` / null: Uses [createRestPermissionCallback] which auto-denies "ask user" requests
/// - `bypassPermissions`: Returns a callback that always allows
///
/// Note: Other modes like `acceptEdits`, `plan`, etc. are handled by Claude CLI itself
/// via the --permission-mode flag. This callback only handles the vide-level permission
/// checks (safe commands, dangerous commands, etc.).
CanUseToolCallback createSmartPermissionCallback(
  PermissionCallbackContext ctx,
) {
  // For 'ask' or 'delegate' mode, use interactive callback that forwards to client
  // Note: Claude CLI doesn't have an 'ask' mode - 'delegate' is the closest equivalent
  // that routes permissions through the SDK callback. When the client requests 'ask',
  // we use the interactive callback which prompts the user via WebSocket.
  if (ctx.permissionMode == 'ask' || ctx.permissionMode == 'delegate') {
    if (ctx.networkId == null) {
      // Can't use interactive mode without session ID - fall back to auto-deny
      return createRestPermissionCallback(ctx.cwd);
    }
    return createInteractivePermissionCallback(
      cwd: ctx.cwd,
      sessionId: ctx.networkId!,
      agentId: ctx.agentId.toString(),
      agentType: ctx.agentType ?? 'unknown',
      agentName: ctx.agentName,
    );
  }

  // For 'bypassPermissions', allow everything
  if (ctx.permissionMode == 'bypassPermissions') {
    return (toolName, rawInput, context) async {
      return const PermissionResultAllow();
    };
  }

  // For all other modes, use the standard REST callback (auto-deny on ask)
  return createRestPermissionCallback(ctx.cwd);
}

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

/// Creates a CanUseToolCallback for interactive REST API sessions.
///
/// Unlike [createRestPermissionCallback], this version forwards [PermissionAskUser]
/// results to the client via WebSocket and waits for a response.
///
/// The [sessionId] is used to route permission requests to the correct session.
/// The [agentId], [agentType], [agentName], and [taskName] are included in
/// permission request events for UI display.
CanUseToolCallback createInteractivePermissionCallback({
  required String cwd,
  required String sessionId,
  required String agentId,
  required String agentType,
  String? agentName,
  String? taskName,
}) {
  // Use default config (askUserBehavior = ask) to get PermissionAskUser results
  final checker = PermissionChecker();

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

    return switch (result) {
      PermissionAllow() => const PermissionResultAllow(),
      PermissionDeny(:final reason) => PermissionResultDeny(message: reason),
      PermissionAskUser(:final inferredPattern) => await _requestPermission(
        sessionId: sessionId,
        toolName: toolName,
        toolInput: rawInput,
        inferredPattern: inferredPattern,
        agentId: agentId,
        agentType: agentType,
        agentName: agentName,
        taskName: taskName,
      ),
    };
  };
}

/// Request permission from the user via the session's WebSocket connection.
Future<PermissionResult> _requestPermission({
  required String sessionId,
  required String toolName,
  required Map<String, dynamic> toolInput,
  String? inferredPattern,
  required String agentId,
  required String agentType,
  String? agentName,
  String? taskName,
}) async {
  final result = await SessionPermissionManager.instance.requestPermission(
    sessionId: sessionId,
    toolName: toolName,
    toolInput: toolInput,
    inferredPattern: inferredPattern,
    agentId: agentId,
    agentType: agentType,
    agentName: agentName,
    taskName: taskName,
  );

  return switch (result) {
    SessionPermissionAllow() => const PermissionResultAllow(),
    SessionPermissionDeny(:final message) => PermissionResultDeny(
      message: message,
    ),
  };
}
