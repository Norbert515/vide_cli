import 'package:agent_sdk/agent_sdk.dart';

import '../control/control_responses.dart';
import '../models/conversation.dart' as claude;
import '../models/message.dart' as claude;
import '../models/response.dart' as claude;

/// Maps a [claude.Conversation] to an [AgentConversation].
class AgentConversationMapper {
  static AgentConversation fromClaude(claude.Conversation c) {
    return AgentConversation(
      messages: c.messages
          .map(AgentConversationMessageMapper.fromClaude)
          .toList(),
      state: _mapState(c.state),
      currentError: c.currentError,
      totalInputTokens: c.totalInputTokens,
      totalOutputTokens: c.totalOutputTokens,
      totalCacheReadInputTokens: c.totalCacheReadInputTokens,
      totalCacheCreationInputTokens: c.totalCacheCreationInputTokens,
      totalCostUsd: c.totalCostUsd,
      currentContextInputTokens: c.currentContextInputTokens,
      currentContextCacheReadTokens: c.currentContextCacheReadTokens,
      currentContextCacheCreationTokens: c.currentContextCacheCreationTokens,
    );
  }

  static AgentConversationState _mapState(claude.ConversationState s) {
    return switch (s) {
      claude.ConversationState.idle => AgentConversationState.idle,
      claude.ConversationState.sendingMessage =>
        AgentConversationState.sendingMessage,
      claude.ConversationState.receivingResponse =>
        AgentConversationState.receivingResponse,
      claude.ConversationState.processing => AgentConversationState.processing,
      claude.ConversationState.error => AgentConversationState.error,
    };
  }
}

/// Maps a [claude.ConversationMessage] to an [AgentConversationMessage].
class AgentConversationMessageMapper {
  static AgentConversationMessage fromClaude(claude.ConversationMessage m) {
    return AgentConversationMessage(
      id: m.id,
      role: _mapRole(m.role),
      content: m.content,
      timestamp: m.timestamp,
      responses: m.responses.map(AgentResponseMapper.fromClaude).toList(),
      isStreaming: m.isStreaming,
      isComplete: m.isComplete,
      error: m.error,
      tokenUsage: m.tokenUsage != null
          ? TokenUsage(
              inputTokens: m.tokenUsage!.inputTokens,
              outputTokens: m.tokenUsage!.outputTokens,
              cacheReadInputTokens: m.tokenUsage!.cacheReadInputTokens,
              cacheCreationInputTokens: m.tokenUsage!.cacheCreationInputTokens,
            )
          : null,
      attachments: m.attachments
          ?.map(
            (a) => AgentAttachment(
              type: a.type,
              path: a.path,
              content: a.content,
              mimeType: a.mimeType,
            ),
          )
          .toList(),
      messageType: _mapMessageType(m.messageType),
    );
  }

  static AgentMessageRole _mapRole(claude.MessageRole r) {
    return switch (r) {
      claude.MessageRole.user => AgentMessageRole.user,
      claude.MessageRole.assistant => AgentMessageRole.assistant,
      claude.MessageRole.system => AgentMessageRole.system,
    };
  }

  static AgentMessageType _mapMessageType(claude.MessageType t) {
    return switch (t) {
      claude.MessageType.userMessage => AgentMessageType.userMessage,
      claude.MessageType.assistantText => AgentMessageType.assistantText,
      claude.MessageType.toolUse => AgentMessageType.toolUse,
      claude.MessageType.toolResult => AgentMessageType.toolResult,
      claude.MessageType.error => AgentMessageType.error,
      claude.MessageType.completion => AgentMessageType.completion,
      claude.MessageType.compactBoundary => AgentMessageType.contextCompacted,
      claude.MessageType.compactSummary => AgentMessageType.unknown,
      claude.MessageType.status => AgentMessageType.unknown,
      claude.MessageType.meta => AgentMessageType.unknown,
      claude.MessageType.unknown => AgentMessageType.unknown,
    };
  }
}

/// Maps a [claude.ClaudeResponse] to an [AgentResponse].
class AgentResponseMapper {
  static AgentResponse fromClaude(claude.ClaudeResponse r) {
    return switch (r) {
      claude.TextResponse() => AgentTextResponse(
        id: r.id,
        timestamp: r.timestamp,
        content: r.content,
        isPartial: r.isPartial,
        isCumulative: r.isCumulative,
        rawData: r.rawData,
      ),
      claude.ToolUseResponse() => AgentToolUseResponse(
        id: r.id,
        timestamp: r.timestamp,
        toolName: r.toolName,
        parameters: r.parameters,
        toolUseId: r.toolUseId,
        rawData: r.rawData,
      ),
      claude.ToolResultResponse() => AgentToolResultResponse(
        id: r.id,
        timestamp: r.timestamp,
        toolUseId: r.toolUseId,
        content: r.content,
        isError: r.isError,
        stdout: r.stdout,
        stderr: r.stderr,
        interrupted: r.interrupted,
        isImage: r.isImage,
        rawData: r.rawData,
      ),
      claude.CompletionResponse() => AgentCompletionResponse(
        id: r.id,
        timestamp: r.timestamp,
        stopReason: r.stopReason,
        inputTokens: r.inputTokens,
        outputTokens: r.outputTokens,
        cacheReadInputTokens: r.cacheReadInputTokens,
        cacheCreationInputTokens: r.cacheCreationInputTokens,
        totalCostUsd: r.totalCostUsd,
        durationApiMs: r.durationApiMs,
        rawData: r.rawData,
      ),
      claude.ErrorResponse() => AgentErrorResponse(
        id: r.id,
        timestamp: r.timestamp,
        error: r.error,
        details: r.details,
        code: r.code,
        rawData: r.rawData,
      ),
      claude.ApiErrorResponse() => AgentApiErrorResponse(
        id: r.id,
        timestamp: r.timestamp,
        level: r.level,
        message: r.message,
        errorType: r.errorType,
        retryInMs: r.retryInMs,
        retryAttempt: r.retryAttempt,
        maxRetries: r.maxRetries,
        rawData: r.rawData,
      ),
      claude.CompactBoundaryResponse() => AgentContextCompactedResponse(
        id: r.id,
        timestamp: r.timestamp,
        trigger: r.trigger,
        preTokens: r.preTokens,
        rawData: r.rawData,
      ),
      claude.UserMessageResponse() => AgentUserMessageResponse(
        id: r.id,
        timestamp: r.timestamp,
        content: r.content,
        isReplay: r.isReplay,
        rawData: r.rawData,
      ),
      claude.CompactSummaryResponse() => AgentTextResponse(
        id: r.id,
        timestamp: r.timestamp,
        content: r.content,
        rawData: r.rawData,
      ),
      claude.StatusResponse() => AgentUnknownResponse(
        id: r.id,
        timestamp: r.timestamp,
        rawData: r.rawData,
      ),
      claude.MetaResponse() => AgentUnknownResponse(
        id: r.id,
        timestamp: r.timestamp,
        rawData: r.rawData,
      ),
      claude.TurnDurationResponse() => AgentUnknownResponse(
        id: r.id,
        timestamp: r.timestamp,
        rawData: r.rawData,
      ),
      claude.LocalCommandResponse() => AgentUnknownResponse(
        id: r.id,
        timestamp: r.timestamp,
        rawData: r.rawData,
      ),
      claude.UnknownResponse() => AgentUnknownResponse(
        id: r.id,
        timestamp: r.timestamp,
        rawData: r.rawData,
      ),
    };
  }
}

/// Maps [claude.ClaudeStatus] to [AgentProcessingStatus].
class AgentStatusMapper {
  static AgentProcessingStatus fromClaude(claude.ClaudeStatus s) {
    return switch (s) {
      claude.ClaudeStatus.ready => AgentProcessingStatus.ready,
      claude.ClaudeStatus.processing => AgentProcessingStatus.processing,
      claude.ClaudeStatus.thinking => AgentProcessingStatus.thinking,
      claude.ClaudeStatus.responding => AgentProcessingStatus.responding,
      claude.ClaudeStatus.completed => AgentProcessingStatus.completed,
      claude.ClaudeStatus.error => AgentProcessingStatus.error,
      claude.ClaudeStatus.unknown => AgentProcessingStatus.unknown,
    };
  }
}

/// Maps [claude.MetaResponse] to [AgentInitData].
class AgentInitDataMapper {
  static AgentInitData fromClaude(claude.MetaResponse r) {
    return AgentInitData(
      model: r.model,
      sessionId: r.sessionId,
      cwd: r.cwd,
      cliVersion: r.claudeCodeVersion,
      permissionMode: r.permissionMode,
      tools: r.tools,
      skills: r.skills,
      metadata: r.metadata,
    );
  }
}

/// Maps [AgentMessage] to [claude.Message].
class AgentMessageMapper {
  static claude.Message toClaude(AgentMessage m) {
    return claude.Message(
      text: m.text,
      attachments: m.attachments
          ?.map(
            (a) => claude.Attachment(
              type: a.type,
              path: a.path,
              content: a.content,
              mimeType: a.mimeType,
            ),
          )
          .toList(),
      metadata: m.metadata,
    );
  }
}

/// Maps [AgentToolResultResponse] to [claude.ToolResultResponse].
class AgentToolResultMapper {
  static claude.ToolResultResponse toClaude(AgentToolResultResponse r) {
    return claude.ToolResultResponse(
      id: r.id,
      timestamp: r.timestamp,
      toolUseId: r.toolUseId,
      content: r.content,
      isError: r.isError,
      stdout: r.stdout,
      stderr: r.stderr,
      interrupted: r.interrupted,
      isImage: r.isImage,
      rawData: r.rawData,
    );
  }
}

/// Maps [McpStatusResponse] to [AgentMcpStatusInfo].
class AgentMcpStatusMapper {
  static AgentMcpStatusInfo fromClaude(McpStatusResponse r) {
    return AgentMcpStatusInfo(
      servers: r.servers.map((s) {
        return AgentMcpServerStatus(name: s.name, status: s.status.name);
      }).toList(),
    );
  }
}

/// Maps [AgentMcpServerConfig] to [McpServerConfig].
class AgentMcpServerConfigMapper {
  static McpServerConfig toClaude(AgentMcpServerConfig c) {
    return McpServerConfig(
      name: c.name,
      command: c.command,
      args: c.args,
      env: c.env,
    );
  }
}
