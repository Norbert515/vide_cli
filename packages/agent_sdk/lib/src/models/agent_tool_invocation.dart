import 'package:path/path.dart' as path;

import 'agent_conversation.dart';

/// Base for file operation tools (Write, Edit, Read, Glob, Grep).
class AgentFileOperationToolInvocation extends AgentToolInvocation {
  final String filePath;

  const AgentFileOperationToolInvocation({
    required super.toolCall,
    super.toolResult,
    required this.filePath,
  });

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

/// Write tool invocation.
class AgentWriteToolInvocation extends AgentFileOperationToolInvocation {
  final String content;

  const AgentWriteToolInvocation({
    required super.toolCall,
    super.toolResult,
    required super.filePath,
    required this.content,
  });

  int getLineCount() {
    if (content.isEmpty) return 0;
    return content.split('\n').length;
  }
}

/// Edit/MultiEdit tool invocation.
class AgentEditToolInvocation extends AgentFileOperationToolInvocation {
  final String oldString;
  final String newString;
  final bool replaceAll;

  const AgentEditToolInvocation({
    required super.toolCall,
    super.toolResult,
    required super.filePath,
    required this.oldString,
    required this.newString,
    this.replaceAll = false,
  });

  bool hasChanges() => oldString != newString;
  int getOldLineCount() => oldString.isEmpty ? 0 : oldString.split('\n').length;
  int getNewLineCount() => newString.isEmpty ? 0 : newString.split('\n').length;
}
