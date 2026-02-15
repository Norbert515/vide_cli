/// Approval types for the Codex app-server.
///
/// When the approval policy allows it, the server sends JSON-RPC requests
/// to the client asking for permission before executing commands or
/// modifying files. The client must respond with a decision.

/// An approval request from the Codex server.
class CodexApprovalRequest {
  /// The JSON-RPC request ID. Must be echoed back in the response.
  final dynamic requestId;

  /// What type of approval is being requested.
  final CodexApprovalType type;

  /// Thread, turn, and item context.
  final String threadId;
  final String turnId;
  final String itemId;

  /// The command to be executed (for command approvals).
  final String? command;

  /// The command's working directory.
  final String? cwd;

  /// Reason for the approval request.
  final String? reason;

  /// Proposed exec-policy amendment to auto-approve similar commands.
  final List<String>? proposedExecpolicyAmendment;

  /// Grant root path for file change approvals.
  final String? grantRoot;

  /// Questions for user input requests.
  final List<Map<String, dynamic>>? questions;

  const CodexApprovalRequest({
    required this.requestId,
    required this.type,
    required this.threadId,
    required this.turnId,
    required this.itemId,
    this.command,
    this.cwd,
    this.reason,
    this.proposedExecpolicyAmendment,
    this.grantRoot,
    this.questions,
  });

  factory CodexApprovalRequest.commandExecution({
    required dynamic requestId,
    required Map<String, dynamic> params,
  }) {
    return CodexApprovalRequest(
      requestId: requestId,
      type: CodexApprovalType.commandExecution,
      threadId: params['threadId'] as String? ?? '',
      turnId: params['turnId'] as String? ?? '',
      itemId: params['itemId'] as String? ?? '',
      command: params['command'] as String?,
      cwd: params['cwd'] as String?,
      reason: params['reason'] as String?,
      proposedExecpolicyAmendment:
          (params['proposedExecpolicyAmendment'] as List<dynamic>?)
              ?.cast<String>(),
    );
  }

  factory CodexApprovalRequest.fileChange({
    required dynamic requestId,
    required Map<String, dynamic> params,
  }) {
    return CodexApprovalRequest(
      requestId: requestId,
      type: CodexApprovalType.fileChange,
      threadId: params['threadId'] as String? ?? '',
      turnId: params['turnId'] as String? ?? '',
      itemId: params['itemId'] as String? ?? '',
      reason: params['reason'] as String?,
      grantRoot: params['grantRoot'] as String?,
    );
  }

  factory CodexApprovalRequest.userInput({
    required dynamic requestId,
    required Map<String, dynamic> params,
  }) {
    return CodexApprovalRequest(
      requestId: requestId,
      type: CodexApprovalType.userInput,
      threadId: params['threadId'] as String? ?? '',
      turnId: params['turnId'] as String? ?? '',
      itemId: params['itemId'] as String? ?? '',
      questions: (params['questions'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>(),
    );
  }
}

/// The type of approval being requested.
enum CodexApprovalType {
  commandExecution,
  fileChange,
  userInput,
}

/// Decision for a command or file change approval request.
enum CodexApprovalDecision {
  /// Approve this specific request.
  accept,

  /// Approve and auto-approve identical requests for the session.
  acceptForSession,

  /// Deny the request. The agent continues the turn.
  decline,

  /// Deny the request and interrupt the turn.
  cancel;

  String toJson() => name;
}
