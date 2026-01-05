/// Type-safe wrapper for tool inputs.
///
/// This sealed class hierarchy provides type-safe access to tool input fields,
/// eliminating the need for unsafe `Map<String, dynamic>` access patterns
/// like `toolInput['command'] as String?`.
sealed class ToolInput {
  const ToolInput();

  /// Parse raw tool input into a type-safe wrapper.
  ///
  /// Returns an [UnknownToolInput] for tools that aren't explicitly modeled.
  factory ToolInput.fromJson(String toolName, Map<String, dynamic> raw) {
    return switch (toolName) {
      'Bash' => BashToolInput.fromJson(raw),
      'Read' => ReadToolInput.fromJson(raw),
      'Write' => WriteToolInput.fromJson(raw),
      'Edit' => EditToolInput.fromJson(raw),
      'MultiEdit' => MultiEditToolInput.fromJson(raw),
      'WebFetch' => WebFetchToolInput.fromJson(raw),
      'WebSearch' => WebSearchToolInput.fromJson(raw),
      'Grep' => GrepToolInput.fromJson(raw),
      'Glob' => GlobToolInput.fromJson(raw),
      _ => UnknownToolInput(toolName: toolName, raw: raw),
    };
  }
}

/// Input for the Bash tool.
class BashToolInput extends ToolInput {
  const BashToolInput({required this.command, this.description, this.timeout});

  factory BashToolInput.fromJson(Map<String, dynamic> raw) {
    return BashToolInput(
      command: raw['command'] as String? ?? '',
      description: raw['description'] as String?,
      timeout: raw['timeout'] as int?,
    );
  }

  /// The bash command to execute.
  final String command;

  /// Optional description of what the command does.
  final String? description;

  /// Optional timeout in milliseconds.
  final int? timeout;
}

/// Input for the Read tool.
class ReadToolInput extends ToolInput {
  const ReadToolInput({required this.filePath, this.offset, this.limit});

  factory ReadToolInput.fromJson(Map<String, dynamic> raw) {
    return ReadToolInput(
      filePath: raw['file_path'] as String? ?? '',
      offset: raw['offset'] as int?,
      limit: raw['limit'] as int?,
    );
  }

  /// The absolute path to the file to read.
  final String filePath;

  /// Optional line number to start reading from.
  final int? offset;

  /// Optional number of lines to read.
  final int? limit;
}

/// Input for the Write tool.
class WriteToolInput extends ToolInput {
  const WriteToolInput({required this.filePath, required this.content});

  factory WriteToolInput.fromJson(Map<String, dynamic> raw) {
    return WriteToolInput(
      filePath: raw['file_path'] as String? ?? '',
      content: raw['content'] as String? ?? '',
    );
  }

  /// The absolute path to the file to write.
  final String filePath;

  /// The content to write to the file.
  final String content;
}

/// Input for the Edit tool.
class EditToolInput extends ToolInput {
  const EditToolInput({
    required this.filePath,
    required this.oldString,
    required this.newString,
    this.replaceAll = false,
  });

  factory EditToolInput.fromJson(Map<String, dynamic> raw) {
    return EditToolInput(
      filePath: raw['file_path'] as String? ?? '',
      oldString: raw['old_string'] as String? ?? '',
      newString: raw['new_string'] as String? ?? '',
      replaceAll: raw['replace_all'] as bool? ?? false,
    );
  }

  /// The absolute path to the file to modify.
  final String filePath;

  /// The text to replace.
  final String oldString;

  /// The text to replace it with.
  final String newString;

  /// Whether to replace all occurrences.
  final bool replaceAll;
}

/// A single edit operation within a MultiEdit.
class EditOperation {
  const EditOperation({required this.oldString, required this.newString});

  factory EditOperation.fromJson(Map<String, dynamic> raw) {
    return EditOperation(
      oldString: raw['old_string'] as String? ?? '',
      newString: raw['new_string'] as String? ?? '',
    );
  }

  /// The text to replace.
  final String oldString;

  /// The text to replace it with.
  final String newString;
}

/// Input for the MultiEdit tool.
class MultiEditToolInput extends ToolInput {
  const MultiEditToolInput({required this.filePath, required this.edits});

  factory MultiEditToolInput.fromJson(Map<String, dynamic> raw) {
    final rawEdits = raw['edits'] as List<dynamic>? ?? [];
    final edits = rawEdits
        .whereType<Map<String, dynamic>>()
        .map(EditOperation.fromJson)
        .toList();

    return MultiEditToolInput(
      filePath: raw['file_path'] as String? ?? '',
      edits: edits,
    );
  }

  /// The absolute path to the file to modify.
  final String filePath;

  /// The list of edit operations to apply.
  final List<EditOperation> edits;
}

/// Input for the WebFetch tool.
class WebFetchToolInput extends ToolInput {
  const WebFetchToolInput({required this.url, this.prompt});

  factory WebFetchToolInput.fromJson(Map<String, dynamic> raw) {
    return WebFetchToolInput(
      url: raw['url'] as String? ?? '',
      prompt: raw['prompt'] as String?,
    );
  }

  /// The URL to fetch content from.
  final String url;

  /// Optional prompt describing what information to extract.
  final String? prompt;
}

/// Input for the WebSearch tool.
class WebSearchToolInput extends ToolInput {
  const WebSearchToolInput({required this.query});

  factory WebSearchToolInput.fromJson(Map<String, dynamic> raw) {
    return WebSearchToolInput(query: raw['query'] as String? ?? '');
  }

  /// The search query to use.
  final String query;
}

/// Input for the Grep tool.
class GrepToolInput extends ToolInput {
  const GrepToolInput({required this.pattern, this.path, this.glob});

  factory GrepToolInput.fromJson(Map<String, dynamic> raw) {
    return GrepToolInput(
      pattern: raw['pattern'] as String? ?? '',
      path: raw['path'] as String?,
      glob: raw['glob'] as String?,
    );
  }

  /// The regular expression pattern to search for.
  final String pattern;

  /// Optional file or directory to search in.
  final String? path;

  /// Optional glob pattern to filter files.
  final String? glob;
}

/// Input for the Glob tool.
class GlobToolInput extends ToolInput {
  const GlobToolInput({required this.pattern, this.path});

  factory GlobToolInput.fromJson(Map<String, dynamic> raw) {
    return GlobToolInput(
      pattern: raw['pattern'] as String? ?? '',
      path: raw['path'] as String?,
    );
  }

  /// The glob pattern to match files against.
  final String pattern;

  /// Optional directory to search in.
  final String? path;
}

/// Input for tools that aren't explicitly modeled.
///
/// Provides access to the raw data while still indicating what tool it's for.
class UnknownToolInput extends ToolInput {
  const UnknownToolInput({required this.toolName, required this.raw});

  /// The name of the tool.
  final String toolName;

  /// The raw input data.
  final Map<String, dynamic> raw;
}
