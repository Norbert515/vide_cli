import 'response.dart';
import 'package:path/path.dart' as path;

/// Represents a tool invocation with its call and optional result
class ToolInvocation {
  final ToolUseResponse toolCall;
  final ToolResultResponse? toolResult;
  final bool isExpanded;
  final String? sessionId;

  const ToolInvocation({
    required this.toolCall,
    this.toolResult,
    this.isExpanded = false,
    this.sessionId,
  });

  bool get hasResult => toolResult != null;
  bool get isComplete => toolResult != null;
  bool get isError => toolResult?.isError ?? false;

  String get toolName => toolCall.toolName;
  Map<String, dynamic> get parameters => toolCall.parameters;
  String? get resultContent => toolResult?.content;

  /// Returns a user-friendly display name for the tool.
  ///
  /// For MCP tools (format: `mcp__server-name__toolName`):
  /// - Formats as "Server Name: toolName"
  ///
  /// For non-MCP tools: returns the tool name as-is.
  String get displayName {
    if (!toolName.startsWith('mcp__')) {
      return toolName; // Non-MCP tools display as-is
    }

    // Parse: mcp__server-name__toolName
    final parts = toolName.substring(5).split('__'); // Remove 'mcp__' prefix
    if (parts.length < 2) return toolName; // Fallback for malformed names

    final serverName = parts[0];
    final tool = parts.sublist(1).join('__'); // In case tool has '__' in it

    // Format server name: "parott-agent" → "Parott Agent"
    final formattedServer = serverName
        .split('-')
        .map(
          (word) =>
              word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '',
        )
        .join(' ');

    return '$formattedServer: $tool';
  }

  ToolInvocation copyWith({
    ToolUseResponse? toolCall,
    ToolResultResponse? toolResult,
    bool? isExpanded,
    String? sessionId,
  }) {
    return ToolInvocation(
      toolCall: toolCall ?? this.toolCall,
      toolResult: toolResult ?? this.toolResult,
      isExpanded: isExpanded ?? this.isExpanded,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

/// Base class for all file operation tools (Write, Edit, MultiEdit, Read, etc.)
/// Provides type-safe access to the file_path parameter.
class FileOperationToolInvocation extends ToolInvocation {
  final String filePath;

  const FileOperationToolInvocation({
    required super.toolCall,
    super.toolResult,
    super.isExpanded,
    super.sessionId,
    required this.filePath,
  });

  factory FileOperationToolInvocation.fromToolInvocation(
    ToolInvocation invocation,
  ) {
    final params = invocation.parameters;
    return FileOperationToolInvocation(
      toolCall: invocation.toolCall,
      toolResult: invocation.toolResult,
      isExpanded: invocation.isExpanded,
      sessionId: invocation.sessionId,
      filePath: params['file_path'] as String? ?? '',
    );
  }

  /// Get the file path relative to the working directory.
  /// If the relative path is shorter, return it; otherwise return the absolute path.
  String getRelativePath(String workingDirectory) {
    if (workingDirectory.isEmpty) return filePath;
    try {
      final p = path.Context(style: path.Style.platform);
      final relative = p.relative(filePath, from: workingDirectory);
      return relative.length < filePath.length ? relative : filePath;
    } catch (e) {
      return filePath;
    }
  }
}

/// Typed invocation for Write tool operations.
/// Provides type-safe access to file_path and content parameters.
class WriteToolInvocation extends FileOperationToolInvocation {
  final String content;

  const WriteToolInvocation({
    required super.toolCall,
    super.toolResult,
    super.isExpanded,
    super.sessionId,
    required super.filePath,
    required this.content,
  });

  factory WriteToolInvocation.fromToolInvocation(ToolInvocation invocation) {
    final params = invocation.parameters;
    return WriteToolInvocation(
      toolCall: invocation.toolCall,
      toolResult: invocation.toolResult,
      isExpanded: invocation.isExpanded,
      sessionId: invocation.sessionId,
      filePath: params['file_path'] as String? ?? '',
      content: params['content'] as String? ?? '',
    );
  }

  /// Get the number of lines in the content.
  int getLineCount() {
    if (content.isEmpty) return 0;
    return content.split('\n').length;
  }
}

/// Typed invocation for Edit and MultiEdit tool operations.
/// Provides type-safe access to file_path, old_string, new_string, and replace_all parameters.
class EditToolInvocation extends FileOperationToolInvocation {
  final String oldString;
  final String newString;
  final bool replaceAll;

  const EditToolInvocation({
    required super.toolCall,
    super.toolResult,
    super.isExpanded,
    super.sessionId,
    required super.filePath,
    required this.oldString,
    required this.newString,
    this.replaceAll = false,
  });

  factory EditToolInvocation.fromToolInvocation(ToolInvocation invocation) {
    final params = invocation.parameters;
    return EditToolInvocation(
      toolCall: invocation.toolCall,
      toolResult: invocation.toolResult,
      isExpanded: invocation.isExpanded,
      sessionId: invocation.sessionId,
      filePath: params['file_path'] as String? ?? '',
      oldString: params['old_string'] as String? ?? '',
      newString: params['new_string'] as String? ?? '',
      replaceAll: params['replace_all'] as bool? ?? false,
    );
  }

  /// Check if this edit makes any actual changes.
  bool hasChanges() => oldString != newString;

  /// Get the number of lines in the old string.
  int getOldLineCount() {
    if (oldString.isEmpty) return 0;
    return oldString.split('\n').length;
  }

  /// Get the number of lines in the new string.
  int getNewLineCount() {
    if (newString.isEmpty) return 0;
    return newString.split('\n').length;
  }
}
